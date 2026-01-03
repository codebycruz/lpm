local ansi = require("ansi")
local fs = require("fs")
local process = require("process")
local path = require("path")

local Package = require("lpm.package")

---@param args clap.Args
local function compile(args)
	local outFile = args:key("outfile", "string")

	local pkg = Package.open()
	if not outFile then
		outFile = path.join(pkg:getDir(), pkg:getName())
	end

	if process.platform == "win32" and string.sub(outFile, -4) ~= ".exe" then
		outFile = outFile .. ".exe"
	end

	local executable = pkg:compile()
	fs.move(executable, outFile)

	print(ansi.colorize(ansi.green, "Executable created: " .. outFile))
end

return compile
