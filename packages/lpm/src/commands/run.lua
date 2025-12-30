local Package = require("lpm.package")

---@param args clap.Args
local function run(args)
	local path = assert(args:pop("string"), "Usage: lpm run whatever.lua")
	local p = Package.openCwd()

	local lpmModulesPath = p.dir .. "/lpm_modules"
	local luaPath = lpmModulesPath .. "/?.lua;" .. lpmModulesPath .. "/?/init.lua;"

	local engine = p.config.engine or "lua"
	local cmd = string.format("LUA_PATH=%q %s %q", luaPath, engine, path)
	os.execute(cmd)
end

return run
