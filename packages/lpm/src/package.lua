local Config = require("lpm.config")
local fs = require("fs")
local json = require("json")

---@class lpm.Package
---@field dir string
---@field config lpm.Config
local Package = {}
Package.__index = Package

---@param path string
function Package.openPath(path)
	local configPath = path .. "/lpm.json"
	if not fs.exists(configPath) then
		error("No lpm.json found in directory: " .. path)
	end

	local file = io.open(configPath, "r")
	if not file then
		error("Could not read lpm.json in directory: " .. path)
	end

	local content = file:read("*all")
	file:close()

	local rawConfig = json.decode(content)
	return setmetatable({ dir = path, config = Config.new(rawConfig) }, Package)
end

function Package.openCwd()
	return Package.openPath(".")
end

---@param path string
function Package.initPath(path)
	local configPath = path .. "/lpm.json"
	if fs.exists(configPath) then
		error("Directory already contains lpm.json: " .. path)
	end

	local config = {
		name = fs.basename(path),
		version = "1.0.0",
		engine = "lua"
	}

	local file = io.open(configPath, "w")
	if file then
		file:write(json.encode(config))
		file:close()
	end

	-- Create src directory and main.lua file
	local srcDir = path .. "/src"
	if not fs.exists(srcDir) then
		fs.mkdir(srcDir)
	end

	local mainPath = srcDir .. "/main.lua"
	local mainFile = io.open(mainPath, "w")
	if mainFile then
		mainFile:write("print('hello world!')")
		mainFile:close()
	end

	return Package.openPath(path)
end

function Package:__tostring()
	return "lpm.Project(" .. self.dir .. ")"
end

return Package
