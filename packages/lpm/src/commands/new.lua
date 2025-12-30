local fs = require("fs")
local ansi = require("ansi")

local Project = require("lpm.project")

---@param args clap.Args
local function new(args)
	local name = assert(args:pop("string"), "Usage: lpm new <name>")

	if fs.exists(name) then
		error("Directory " .. name .. " already exists")
	end

	fs.mkdir(name)
	print(ansi.colorize(ansi.green, "Created directory: " .. name))

	Project.initPath(fs.cwd() .. "/" .. name)
end

return new
