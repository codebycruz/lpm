---@class lpm.Config
---@field name string
---@field version string
---@field engine? string
---@field dependencies? table<string, lpm.Config.Dependency>
local Config = {}
Config.__index = Config

---@param conf lpm.Config
function Config.new(conf)
	return setmetatable(conf, Config) --[[@as lpm.Config]]
end

---@class lpm.Config.GitDependency
---@field git string

---@class lpm.Config.PathDependency
---@field path string

---@alias lpm.Config.Dependency
--- | lpm.Config.GitDependency
--- | lpm.Config.PathDependency

return Config
