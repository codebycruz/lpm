local ansi = require("ansi")
local fs = require("fs")
local path = require("path")

local lde = require("lde-core")

---@param args clap.Args
local function compile(args)
	local outFile = args:option("outfile")
	local shared = args:flag("shared")

	local pkg, err = lde.Package.open()
	if not pkg then
		ansi.printf("{red}%s", err)
		return
	end

	if not outFile then
		local ext = ""
		if jit.os == "Windows" then
			ext = shared and ".dll" or ".exe"
		elseif jit.os == "OSX" then
			ext = shared and ".dylib" or ""
		else
			ext = shared and ".so" or ""
		end
		outFile = path.join(pkg:getDir(), pkg:getName()) .. ext
	end

	if not shared and jit.os == "Windows" and string.sub(outFile, -4) ~= ".exe" then
		outFile = outFile .. ".exe"
	end

	local output
	if shared then
		output = pkg:compileShared()
	else
		output = pkg:compile()
	end

	local ok, moveErr = fs.move(output, outFile)
	if not ok then
		error("Failed to move output: " .. moveErr)
	end

	if jit.os ~= "Windows" then ---@cast fs fs.raw.posix
		fs.chmod(outFile, tonumber("755", 8))
	end

	if shared then
		ansi.printf("{green}Shared library created: %s", outFile)
	else
		ansi.printf("{green}Executable created: %s", outFile)
	end
end

return compile
