local ansi = require("ansi")

---@param args clap.Args
local function help(args)
	local commands = {
		{ cmd = "run",     ex = "foo.lua",   color = ansi.green,   desc = "Execute a lua script" },
		{},
		{ cmd = "new",     ex = "myproject", color = ansi.red,     desc = "Create a new lpm project" },
		{ cmd = "init",    ex = nil,         color = ansi.red,     desc = "Initialize current directory as lpm project" },
		{},
		{ cmd = "install", ex = nil,         color = ansi.yellow,  desc = "Install project dependencies" },
		{ cmd = "add",     ex = "gfx",       color = ansi.yellow,  desc = "Add a dependency (--path <path> or --git <url>)" },
		{},
		{ cmd = "bundle",  ex = nil,         color = ansi.magenta, desc = "Bundle current project into executable" }
	}

	print("lpm is a package manager for Lua, written in Lua.\n")
	print("Usage: lpm <command> [options]")
	print("Available commands:")
	for _, command in ipairs(commands) do
		if not command.cmd then -- Separator
			print("")
		else
			local cmd = ansi.colorize(command.color, command.cmd)
			local ex = ansi.colorize(ansi.gray, command.ex or "")

			print(string.format("  %-18s %-20s %s", cmd, ex, command.desc))
		end
	end
end

return help
