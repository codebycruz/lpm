local Config = require("lpm.config")
local fs = require("lpm.fs")
local json = require("lpm.json")

---@class lpm.Project
---@field dir string
---@field config lpm.Config
local Project = {}
Project.__index = Project

---@param path string
function Project.new(path)
	local self = setmetatable({}, Project)
	self.dir = path

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
	self.config = Config.new(rawConfig)

	return self
end

function Project.fromCwd()
	return Project.new(".")
end

function Project:__tostring()
	return "lpm.Project(" .. self.dir .. ")"
end

return Project
