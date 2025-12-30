local fs = require("fs")

local Project = require("lpm.project")

---@param args clap.Args
local function init(args)
	local path = args:pop("string") or fs.cwd()
	local name = fs.basename(path)
	Project.initPath(path, name)
end

return init
