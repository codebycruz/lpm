local json = require("json")
local ansi = require("ansi")
local fs = require("fs")

local Package = require("lpm-core.package")

---@param args clap.Args
local function remove(args)
	local name = assert(args:pop("string"), "Usage: lpm remove <name>")

	local p = Package.open()
	local configPath = p:getConfigPath()

	local config = json.decode(fs.read(p:getConfigPath()))
	if not config.dependencies then
		config.dependencies = {}
	end

	if not config.dependencies[name] then
		ansi.printf("{yellow}Dependency does not exist: %s", name)
		return
	end

	config.dependencies[name] = nil

	fs.write(configPath, json.encode(config))

	ansi.printf("{green}Removed dependency: %s", name)
end

return remove
