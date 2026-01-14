local env = require("env")

local Package = require("lpm.package")

---@param args clap.Args
local function init(args)
	local path = args:pop("string") or env.cwd()
	Package.init(path)
end

return init
