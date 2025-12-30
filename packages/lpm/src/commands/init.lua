local fs = require("fs")

local Package = require("lpm.package")

---@param args clap.Args
local function init(args)
	local path = args:pop("string") or fs.cwd()
	local name = fs.basename(path)
	Package.initPath(path, name)
end

return init
