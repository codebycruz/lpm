local Config = require("lpm.config")
local fs = require("fs")
local json = require("json")

---@class lpm.Project
---@field dir string
---@field config lpm.Config
local Project = {}
Project.__index = Project

---@param path string
function Project.openPath(path)
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
	return setmetatable({ dir = path, config = Config.new(rawConfig) }, Project)
end

function Project.openCwd()
	return Project.openPath(".")
end

---@param path string
function Project.initPath(path)
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

	return Project.openPath(path)
end

function Project:__tostring()
	return "lpm.Project(" .. self.dir .. ")"
end

return Project
