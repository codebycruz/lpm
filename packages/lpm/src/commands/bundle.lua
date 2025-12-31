local ansi = require("ansi")

---@param args clap.Args
local function bundle(args)
	local outFile = args:key("outfile", "string")
	if not outFile then
		error("Please specify an output file using --outfile")
	end

	print(ansi.colorize(ansi.red, "Bundling is not yet implemented."))
end

return bundle
