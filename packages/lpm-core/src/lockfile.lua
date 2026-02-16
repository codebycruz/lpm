local fs = require("fs")
local json = require("json")
local path = require("path")

---@class lpm.Lockfile.Raw.GitDependency
---@field git string
---@field commit string
---@field branch string

---@class lpm.Lockfile.Raw.PathDependency
---@field path string

---@alias lpm.Lockfile.Raw.Dependency
--- | lpm.Lockfile.Raw.GitDependency
--- | lpm.Lockfile.Raw.PathDependency

---@class lpm.Lockfile.Raw
---@field version "1"
---@field dependencies table<string, lpm.Lockfile.Raw.Dependency>

---@class lpm.Lockfile
---@field path string
---@field raw lpm.Lockfile.Raw
local Lockfile = {}
Lockfile.__index = Lockfile

---@param p string
function Lockfile.open(p)
	local content = fs.read(p)
	if not content then
		error("Could not read lockfile: " .. p)
	end

	return setmetatable({ path = p, raw = json.decode(content) }, Lockfile)
end

---@param p string
---@param dependencies table<string, lpm.Lockfile.Raw.Dependency>
function Lockfile.new(p, dependencies)
	return setmetatable({
		path = p,
		raw = {
			version = "1",
			dependencies = dependencies,
		},
	}, Lockfile)
end

function Lockfile:save()
	local content = json.encode(self.raw)
	return fs.write(self.path, content)
end

function Lockfile:getVersion()
	return self.raw.version
end

function Lockfile:getDependencies()
	if self:getVersion() == "1" then
		return self.raw.dependencies
	else
		error("Unsupported lockfile version: " .. tostring(self.raw.version))
	end
end

function Lockfile:getDependency(name)
	return self:getDependencies()[name]
end

return Lockfile
