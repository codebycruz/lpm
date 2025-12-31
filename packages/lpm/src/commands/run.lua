local Package = require("lpm.package")

---@param args clap.Args
local function run(args)
	local file = assert(args:pop("string"), "Usage: lpm run whatever.lua")
	Package.open():runScript(file)
end

return run
