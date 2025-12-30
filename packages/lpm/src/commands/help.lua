local ansi = require("ansi")

---@param args clap.Args
local function help(args)
	print("Available commands:")
	print("  " .. ansi.colorize(ansi.red, "new <name>") .. "      Create a new lpm project")
	print("  " .. ansi.colorize(ansi.red, "init") .. "            Initialize current directory as lpm project")
	print("  " .. ansi.colorize(ansi.orange, "add <name>") .. "       Add a dependency (--path <path> or --git <url>)")
	print("  " .. ansi.colorize(ansi.orange, "install (i)") .. "     Install project dependencies")
	print("  " .. ansi.colorize(ansi.green, "run <script>") .. "    Run a Lua script with dependencies")
	print("  " .. ansi.colorize(ansi.magenta, "bundle [outfile]") .. " Bundle current project into executable")
	print("  " .. ansi.colorize(ansi.blue, "help") .. "            Show this help message")
end

return help
