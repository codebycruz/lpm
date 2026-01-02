local ansi = require("ansi")
local fs = require("fs")
local process = require("process")

local Package = require("lpm.package")

---@param args clap.Args
local function compile(args)
	local outFile = args:key("outfile", "string")
	if not outFile then
		error("Please specify an output file using --outfile")
	end

	if process.platform == "win32" then
		if string.sub(outFile, -4) ~= ".exe" then
			outFile = outFile .. ".exe"
		end
	end

	local executable = Package.open():compile()
	fs.move(executable, outFile)

	print(ansi.colorize(ansi.green, "Bundle created: " .. outFile))
end

return compile
