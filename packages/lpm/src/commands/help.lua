local ansi = require("ansi")

---@param args clap.Args
local function help(args)
	local commands = {
		{ cmd = "run",     ex = "foo.lua",     color = "green",   desc = "Execute a lua script" },
		{ cmd = "x",       ex = "--git <url>", color = "green",   desc = "Run a package from a git repo or path" },
		{ cmd = "test",    ex = nil,           color = "green",   desc = "Run project tests" },
		{},
		{ cmd = "new",     ex = "myproject",   color = "red",     desc = "Create a new lpm project" },
		{ cmd = "init",    ex = nil,           color = "red",     desc = "Initialize current directory as lpm project" },
		{ cmd = "upgrade", ex = nil,           color = "red",     desc = "Upgrade lpm to the latest version" },
		{},
		{ cmd = "install", ex = nil,           color = "yellow",  desc = "Install project dependencies" },
		{ cmd = "add",     ex = "gfx",         color = "yellow",  desc = "Add a dependency (--path <path> or --git <url>)" },
		{ cmd = "remove",  ex = "json",        color = "yellow",  desc = "Remove a dependency" },
		{ cmd = "tree",    ex = nil,           color = "yellow",  desc = "Show the dependency tree" },
		{},
		{ cmd = "compile", ex = nil,           color = "magenta", desc = "Compile current project into an executable" },
		{ cmd = "bundle",  ex = nil,           color = "magenta", desc = "Bundle current project into a single lua file" }
	}

	print("lpm is a package manager for Lua, written in Lua.\n")
	print("Usage: lpm <command> [options]")
	print("Available commands:")
	for _, command in ipairs(commands) do
		if not command.cmd then -- Separator
			print("")
		else
			local cmd = ansi.colorize(command.color, command.cmd)
			local ex = ansi.colorize("gray", command.ex or "")

			print(string.format("  %-18s %-20s %s", cmd, ex, command.desc))
		end
	end
end

return help
