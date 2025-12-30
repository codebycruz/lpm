local Package = require("lpm.package")

local path = require("path")

---@param args clap.Args
local function run(args)
	local file = assert(args:pop("string"), "Usage: lpm run whatever.lua")

	local p = Package.open()
	local modulesDir = p:getModulesDir()
	local luaPath = modulesDir .. "/?.lua;" .. modulesDir .. "/?/init.lua;"

	local engine = p:readConfig().engine or "lua"
	local cmd = string.format("LUA_PATH=%q %s %q", luaPath, engine, file)
	os.execute(cmd)
end

return run
