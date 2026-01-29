local fs = require("fs")
local ansi = require("ansi")
local path = require("path")
local env = require("env")

local Package = require("lpm-core.package")

---@param args clap.Args
local function new(args)
	local name = assert(args:pop("string"), "Usage: lpm new <name>")

	if fs.exists(name) then
		error("Directory " .. name .. " already exists")
	end

	fs.mkdir(name)
	ansi.printf("{green}Created directory: %s", name)

	Package.init(path.join(env.cwd(), name))
end

return new
