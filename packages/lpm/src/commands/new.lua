local fs = require("fs")
local ansi = require("ansi")
local path = require("path")
local env = require("env")

local Package = require("lpm.package")

---@param args clap.Args
local function new(args)
	local name = assert(args:pop("string"), "Usage: lpm new <name>")

	if fs.exists(name) then
		error("Directory " .. name .. " already exists")
	end

	fs.mkdir(name)
	print(ansi.colorize(ansi.green, "Created directory: " .. name))

	Package.init(path.join(env.cwd(), name))
end

return new
