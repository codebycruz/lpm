local ansi = require("ansi")

---@param args clap.Args
local function help(args)
	local commands = {
		{ cmd = "run",     ex = "foo.lua",   color = ansi.green,   desc = "Execute a lua script" },
		{ cmd = "test",    ex = nil,         color = ansi.green,   desc = "Run project tests" },
		{},
		{ cmd = "new",     ex = "myproject", color = ansi.red,     desc = "Create a new lpm project" },
		{ cmd = "init",    ex = nil,         color = ansi.red,     desc = "Initialize current directory as lpm project" },
		{ cmd = "upgrade", ex = nil,         color = ansi.red,     desc = "Upgrade lpm to the latest version" },
		{},
		{ cmd = "install", ex = nil,         color = ansi.yellow,  desc = "Install project dependencies" },
		{ cmd = "add",     ex = "gfx",       color = ansi.yellow,  desc = "Add a dependency (--path <path> or --git <url>)" },
		{ cmd = "remove",  ex = "json",      color = ansi.yellow,  desc = "Remove a dependency" },
		{},
		{ cmd = "compile", ex = nil,         color = ansi.magenta, desc = "Compile current project into an executable" },
		{ cmd = "bundle",  ex = nil,         color = ansi.magenta, desc = "Bundle current project into a single lua file" }
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
