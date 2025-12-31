local Config = require("lpm.config")
local global = require("lpm.global")

local fs = require("fs")
local json = require("json")
local path = require("path")
local sea = require("sea")
local process = require("process")

---@class lpm.Package
---@field dir string
local Package = {}
Package.__index = Package

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

	local file = io.open(configPath, "r")
	if not file then
		error("Could not read lpm.json in directory: " .. configPath)
	end

	local content = file:read("*all")
	file:close()

	return Config.new(json.decode(content))
end

---@param dir string
function Package.init(dir)
	local configPath = path.join(dir, "lpm.json")
	if fs.exists(configPath) then
		error("Directory already contains lpm.json: " .. dir)
	end

	---@type lpm.Config
	local config = {
		name = fs.basename(dir),
		version = "0.1.0",
		engine = "lua"
	}

	local file = io.open(configPath, "w")
	if file then
		file:write(json.encode(config))
		file:close()
	end

	local package = Package.open(dir)

	local src = package:getSrcDir()
	if not fs.exists(src) then
		fs.mkdir(src)

		local initHandle = io.open(path.join(src, "init.lua"), "w")
		if initHandle then
			initHandle:write('print("Hello, world!")')
			initHandle:close()
		end
	end

	return package
end

function Package:__tostring()
	return "Package(" .. self.dir .. ")"
end

function Package:getDependencies()
	return self:readConfig().dependencies or {}
end

function Package:getName()
	return self:readConfig().name
end

--- TODO: Add luarc changing stuff again
---@param dependencies table<string, lpm.Config.Dependency>?
---@param installed table<string, boolean>?
function Package:installDependencies(dependencies, installed)
	dependencies = dependencies or self:getDependencies()
	installed = installed or {}

	local modulesDir = self:getModulesDir()
	if not fs.exists(modulesDir) then
		fs.mkdir(modulesDir)
	end

	for name, depInfo in pairs(dependencies) do
		if installed and installed[name] then
			goto skip
		end

		local destinationPath = path.join(modulesDir, name)
		if fs.exists(destinationPath) then
			goto skip
		end

		if depInfo.git then
			local repoDir = global.getOrInitGitRepo(name, depInfo.git)

			for _, config in ipairs(fs.scan(repoDir, "**/lpm.json")) do
				local parentDir = path.join(repoDir, path.dirname(config))
				local package = Package.open(parentDir)

				if package:getName() == name then
					self:installDependencies(package:getDependencies(), installed)

					local packageSrcPath = package:getSrcDir()
					if not fs.exists(packageSrcPath) then
						error("Dependency " .. name .. " has no src directory")
					end

					installed[name] = true
					fs.mklink(packageSrcPath, destinationPath)
				end
			end
		elseif depInfo.path then
			local dependency = Package.open(path.resolve(self.dir, depInfo.path))
			self:installDependencies(dependency:getDependencies(), installed)

			local dependencySrcPath = path.resolve(self.dir, dependency:getSrcDir())
			if not fs.exists(dependencySrcPath) then
				error("Dependency " .. name .. " has no src directory")
			end

			installed[dependency:getName()] = true

			fs.mklink(dependencySrcPath, destinationPath)
		else
			error("Unsupported dependency type for: " .. name)
		end

		::skip::
	end
end

function Package:bundle()
	self:installDependencies()

	---@type table<{path: string, content: string}>
	local files = {}

	---@param dir string
	local function bundleDir(projectName, dir)
		for _, relativePath in ipairs(fs.scan(dir, "**/*.lua")) do
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
---@return boolean? # Success
---@return string # Output
function Package:runScript(scriptPath)
	local modulesDir = self:getModulesDir()

	local luaPath = path.join(modulesDir, "?.lua") .. ";" .. path.join(modulesDir, "?", "init.lua") .. ";"
	local engine = self:readConfig().engine or "lua"

	return process.exec(engine, { scriptPath }, { env = { LUA_PATH = luaPath } })
end

return Package
