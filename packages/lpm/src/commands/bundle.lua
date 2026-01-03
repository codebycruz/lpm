local ansi = require("ansi")
local path = require("path")

local Package = require("lpm.package")

---@param args clap.Args
local function bundle(args)
	local outFile = args:key("outfile", "string")

	local pkg = Package.open()
	if not outFile then
		outFile = path.join(pkg:getDir(), pkg:getName() .. "-bundled.lua")
	end

	print(ansi.colorize(ansi.red, "Bundling is not yet implemented."))
end

return bundle
