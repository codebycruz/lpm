local Config = require("lpm.config")
local Lockfile = require("lpm.lockfile")
local global = require("lpm.global")

local fs = require("fs")
local json = require("json")
local path = require("path")
local sea = require("sea")
local process = require("process")
local util = require("util")

---@class lpm.Package
---@field dir string
local Package = {}
Package.__index = Package

function Package:getDir()
	return self.dir
end

function Package:getBuildScriptPath()
	return path.join(self.dir, "build.lua")
end

function Package:getLuarcPath()
	return path.join(self.dir, ".luarc.json")
end

function Package:getModulesDir()
	return path.join(self.dir, "lpm_modules")
end

function Package:getSrcDir()
	return path.join(self.dir, "src")
end

function Package:getTestDir()
	return path.join(self.dir, "tests")
end

function Package:getConfigPath()
	return path.join(self.dir, "lpm.json")
end

function Package:getLockfilePath()
	return path.join(self.dir, "lpm-lock.json")
end

---@param dir string?
function Package.open(dir)
	dir = dir or fs.cwd()

	local configPath = path.join(dir, "lpm.json")
	if not fs.exists(configPath) then
		error("No lpm.json found in directory: " .. dir)
	end

	return setmetatable({ dir = dir }, Package)
end

---@return lpm.Config
function Package:readConfig()
	local configPath = self:getConfigPath()

	local content = fs.read(configPath)
	if not content then
		error("Could not read lpm.json: " .. configPath)
	end

	return Config.new(json.decode(content))
end

function Package:readLockfile()
	return Lockfile.open(self:getLockfilePath())
end

---@param dir string
function Package.init(dir)
	local configPath = path.join(dir, "lpm.json")
	if fs.exists(configPath) then
		error("Directory already contains lpm.json: " .. dir)
	end

	fs.write(configPath, util.dedent [[
		{
			"name": "]] .. fs.basename(dir) .. [[",
			"version": "0.1.0",
			"engine": "lua",
			"main": "src/init.lua"
		}
	]])

	local package = Package.open(dir)

	local src = package:getSrcDir()
	if not fs.exists(src) then
		fs.mkdir(src)
		fs.write(path.join(src, "init.lua"), "print('Hello, world!')")
	end

	return package
end

function Package:__tostring()
	return "Package(" .. self.dir .. ")"
end

function Package:getDependencies()
	return self:readConfig().dependencies or {}
end

function Package:getDevDependencies()
	return self:readConfig().devDependencies or {}
end

function Package:getName()
	return self:readConfig().name
end

---@param destinationPath string
function Package:build(destinationPath)
	local buildScriptPath = self:getBuildScriptPath()
	if fs.exists(buildScriptPath) then
		fs.copy(self:getSrcDir(), destinationPath)

		local ok, err = self:runScript(buildScriptPath, { LPM_OUTPUT_DIR = destinationPath })
		if not ok then
			error("Build script failed for package '" .. self:getName() .. "': " .. err)
		end
	else
		fs.mklink(self:getSrcDir(), destinationPath)
	end
end

---@param dependency lpm.Package
function Package:installDependency(dependency)
	self:installDependencies(dependency:getDependencies(), dependency:getDir())

	local modulesDir = self:getModulesDir()
	if not fs.exists(modulesDir) then
		fs.mkdir(modulesDir)
	end

	local destinationPath = path.join(modulesDir, dependency:getName())
	if fs.exists(destinationPath) then
		return
	end

	dependency:build(destinationPath)
end

--- TODO: Add luarc changing stuff again
---@param dependencies table<string, lpm.Config.Dependency>?
---@param relativeTo string? # Directory to resolve relative paths from
function Package:installDependencies(dependencies, relativeTo)
	dependencies = dependencies or self:getDependencies()
	relativeTo = relativeTo or self.dir

	local modulesDir = self:getModulesDir()
	if not fs.exists(modulesDir) then
		fs.mkdir(modulesDir)
	end

	for name, depInfo in pairs(dependencies) do
		local destinationPath = path.join(modulesDir, name)
		if fs.exists(destinationPath) then
			goto skip
		end

		if depInfo.git then
			local repoDir = global.getOrInitGitRepo(name, depInfo.git)

			for _, config in ipairs(fs.scan(repoDir, "**" .. path.separator .. "lpm.json")) do
				local parentDir = path.join(repoDir, path.dirname(config))
				local package = Package.open(parentDir)

				if package:getName() == name then
					self:installDependency(package)
				end
			end
		elseif depInfo.path then
			local normalized = path.normalize(depInfo.path)
			self:installDependency(Package.open(path.resolve(relativeTo, normalized)))
		else
			error("Unsupported dependency type for: " .. name)
		end

		::skip::
	end
end

function Package:installDevDependencies()
	self:installDependencies(self:getDevDependencies())
end

-- TODO: Support build step? Hmm.
function Package:compile()
	self:installDependencies()

	---@type table<{path: string, content: string}>
	local files = {}

	---@param dir string
	local function bundleDir(projectName, dir)
		for _, relativePath in ipairs(fs.scan(dir, "**" .. path.separator .. "*.lua")) do
			local absPath = path.join(dir, relativePath)
			local content = fs.read(absPath)
			if not content then
				error("Could not read file: " .. absPath)
			end

			local moduleName = projectName
			if relativePath ~= "init.lua" then
				moduleName = projectName .. "." .. relativePath:gsub(path.separator, "."):gsub("%.lua$", "")
			end

			table.insert(files, { path = moduleName, content = content })
		end
	end

	bundleDir(self:getName(), self:getSrcDir())

	-- Use the lpm_modules directory for the build artifacts rather than src,
	-- since in the future build scripts will be added that may modify src contents.
	local modulesDir = self:getModulesDir()
	for depName in pairs(self:getDependencies()) do
		local buildFolder = path.join(modulesDir, depName)
		bundleDir(depName, buildFolder)
	end

	return sea.compile(self:getName(), files)
end

--- Runs a script within the package context
--- This will use the package's engine and set up the LUA_PATH accordingly
---@param scriptPath string
---@param vars table<string, string>? # Additional environment variables
---@return boolean? # Success
---@return string # Output
function Package:runScript(scriptPath, vars)
	local modulesDir = self:getModulesDir()

	if not fs.isdir(modulesDir) then
		fs.mkdir(modulesDir)
		-- return false, "Modules directory does not exist: " .. modulesDir
	end

	local selfPackage = path.join(modulesDir, self:getName())
	if not fs.islink(selfPackage) then
		-- Create symlink to self's source dir in lpm_modules so that require(<self>) works
		fs.mklink(self:getSrcDir(), selfPackage)
	end

	local luaPath =
		path.join(modulesDir, "?.lua") .. ";"
		.. path.join(modulesDir, "?", "init.lua") .. ";"

	local luaCPath =
		path.join(modulesDir, "?.so") .. ";"
		.. path.join(modulesDir, "?.dll") .. ";"

	local engine = self:readConfig().engine
	if not engine then
		print("Warning: No engine specified for package '" .. self:getName() .. "', defaulting to 'lua'.")
		engine = "lua"
	end

	local env = { LUA_PATH = luaPath, LUA_CPATH = luaCPath }
	if vars then
		for k, v in pairs(vars) do
			env[k] = v
		end
	end

	return process.exec(engine, { scriptPath }, { cwd = self:getDir(), env = env })
end

return Package
