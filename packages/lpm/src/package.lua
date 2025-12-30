local Config = require("lpm.config")

local fs = require("fs")
local json = require("json")
local path = require("path")

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

		local initHandle = io.open(src .. "/init.lua", "w")
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

		if depInfo.git then
			error("Git dependencies are not yet supported: " .. name)
		elseif depInfo.path then
			local destinationPath = path.join(modulesDir, name)
			if fs.exists(destinationPath) then
				goto skip
			end

			local dependency = Package.open(fs.resolve(self.dir, depInfo.path))
			self:installDependencies(dependency:getDependencies(), installed)

			local dependencySrcPath = fs.resolve(self.dir, dependency:getSrcDir())
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

return Package
