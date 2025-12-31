local Package = require("lpm.package")

local path = require("path")

---@param args clap.Args
local function run(args)
	local file = assert(args:pop("string"), "Usage: lpm run whatever.lua")

	local p = Package.open()
	local modulesDir = p:getModulesDir()
	local luaPath = path.join(modulesDir, "?.lua") .. ";" .. path.join(modulesDir, "?", "init.lua") .. ";"

	local engine = p:readConfig().engine or "lua"
	os.execute(("LUA_PATH=%q %s %q"):format(luaPath, engine, file))
end

return run
