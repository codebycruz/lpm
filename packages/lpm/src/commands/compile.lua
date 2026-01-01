local ansi = require("ansi")
local fs = require("fs")

local Package = require("lpm.package")

---@param args clap.Args
local function compile(args)
	local outFile = args:key("outfile", "string")
	if not outFile then
		error("Please specify an output file using --outfile")
	end

	if string.sub(outFile, -4) ~= ".exe" then
		outFile = outFile .. ".exe"
	end

	local executable = Package.open():compile()
	fs.move(executable, outFile)

	print(ansi.colorize(ansi.green, "Bundle created: " .. outFile))
end

return compile
