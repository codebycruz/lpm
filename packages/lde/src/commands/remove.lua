local json = require("json")
local ansi = require("ansi")
local fs = require("fs")
local path = require("path")

local lde = require("lde-core")

---@param args clap.Args
local function remove(args)
	local name = assert(args:pop(), "Usage: lde remove <name>")

	local pkg, err = lde.Package.open()
	if not pkg then
		ansi.printf("{red}%s", err)
		return
	end

	local configPath = pkg:getConfigPath()

	local configRaw = fs.read(configPath)
	if not configRaw then
		ansi.printf("{red}Failed to read config: %s", configPath)
		return
	end

	local config = json.decode(configRaw)
	if not config.dependencies then
		config.dependencies = {}
	end

	if not config.dependencies[name] then
		ansi.printf("{yellow}Dependency does not exist: %s", name)
		return
	end

	json.removeField(config.dependencies, name)

	fs.write(configPath, json.encode(config))

	local lockfile = pkg:readLockfile()
	if lockfile then
		json.removeField(lockfile.raw.dependencies, name)
		lockfile:save()
	end

	fs.delete(path.join(pkg:getModulesDir(), ".installed"))

	ansi.printf("{green}Removed dependency: %s", name)
end

return remove
