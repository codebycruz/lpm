local json = require("json")
local ansi = require("ansi")
local fs = require("fs")

local Package = require("lpm.package")

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
		print(ansi.colorize(ansi.yellow, "Dependency does not exist: " .. name))
		return
	end

	config.dependencies[name] = nil

	fs.write(configPath, json.encode(config))

	print(ansi.colorize(ansi.green, "Removed dependency: " .. name))
end

return remove
