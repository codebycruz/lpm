-- Bootstrapping mode for initial creation of an lpm binary for a platform.
-- Heavily unoptimized, do not use this.
if os.getenv("BOOTSTRAP") then
	local scriptPath = debug.getinfo(1, "S").source:sub(2)
	local srcDir = scriptPath:match("^(.*)[/\\]")
	local baseDir = srcDir:match("^(.*)[/\\]")

	package.path = baseDir .. "/target/?.lua;" ..
		baseDir .. "/target/?/init.lua;" ..
		package.path

	local separator = package.config:sub(1, 1)

	local function join(...)
		return table.concat({ ... }, separator)
	end

	local isWindows = separator == '\\'
	local lpmModulesDir = join(baseDir, "target")

	local function exists(path)
		local ok, _, code = os.rename(path, path)

		if not ok then
			if code == 13 then -- permission denied but exists
				return true
			end

			return false
		end

		return true
	end

	if not exists(lpmModulesDir) then
		if isWindows then
			os.execute('mkdir "' .. lpmModulesDir .. '"')
		else
			os.execute('mkdir -p "' .. lpmModulesDir .. '"')
		end
	end

	local pathPackages = {
		"ansi", "clap", "fs", "http", "env", "path", "json",
		"process", "sea", "semver", "util", "lpm-core", "lpm-test"
	}

	for _, pkg in ipairs(pathPackages) do
		-- Semantics of the 'src' differ between windows and linux symlinks
		local relSrcPath = join("..", "..", pkg, "src")
		local absSrcPath = join(baseDir, "..", pkg, "src")

		local moduleDistPath = join(lpmModulesDir, pkg)
		if not exists(moduleDistPath) then
			if isWindows then
				os.execute('mklink /J "' .. moduleDistPath .. '" "' .. absSrcPath .. '"')
			else
				os.execute("ln -sf '" .. relSrcPath .. "' '" .. moduleDistPath .. "'")
			end
		end
	end

	local moduleDistPath = join(lpmModulesDir, "lpm")
	if not exists(moduleDistPath) then
		local relSrcPath = join("..", "src")
		local absSrcPath = join(baseDir, "src")

		if isWindows then
			os.execute('mklink /J "' .. moduleDistPath .. '" "' .. absSrcPath .. '"')
		else
			os.execute("ln -sf '" .. relSrcPath .. "' '" .. moduleDistPath .. "'")
		end
	end
end

local ansi = require("ansi")
local clap = require("clap")
local env = require("env")
local fs = require("fs")
local process = require("process")

local global = require("lpm-core.global")
global.init()

local args = clap.parse({ ... })

if args:flag("version") and args:count() == 0 then
	print(global.currentVersion)
	return
end

if args:flag("update-path") then
	local lpmDir = global.getDir()
	local toolsDir = global.getToolsDir()

	if process.platform == "win32" then
		-- Read current user PATH, append missing dirs, write back via PowerShell
		local getCmd = '[Environment]::GetEnvironmentVariable("Path","User")'
		local ok, currentPath = process.exec("powershell", { "-NoProfile", "-Command", getCmd })
		if not ok then
			ansi.printf("{red}Failed to read user PATH from registry")
			return
		end
		currentPath = currentPath and currentPath:gsub("%s+$", "") or ""

		local dirsToAdd = {}
		if not currentPath:find(lpmDir, 1, true) then
			dirsToAdd[#dirsToAdd + 1] = lpmDir
		end
		if not currentPath:find(toolsDir, 1, true) then
			dirsToAdd[#dirsToAdd + 1] = toolsDir
		end

		if #dirsToAdd == 0 then
			ansi.printf("{green}PATH is already up to date.")
			return
		end

		local sep = (currentPath ~= "" and not currentPath:match(";$")) and ";" or ""
		local newPath = currentPath .. sep .. table.concat(dirsToAdd, ";")
		local setCmd = string.format('[Environment]::SetEnvironmentVariable("Path","%s","User")', newPath)
		local setOk, setErr = process.spawn("powershell", { "-NoProfile", "-Command", setCmd })
		if not setOk then
			ansi.printf("{red}Failed to update PATH: %s", setErr or "unknown error")
			return
		end
		for _, d in ipairs(dirsToAdd) do
			ansi.printf("{green}Added to PATH: %s", d)
		end
		ansi.printf("{yellow}Restart your terminal for the change to take effect.")
	else
		-- Unix: patch the first shell rc file that already mentions .lpm, or
		-- the first that exists among the standard candidates.
		local home = os.getenv("HOME") or ""
		local rcFiles = {
			home .. "/.zshrc",
			home .. "/.bashrc",
			home .. "/.profile",
		}

		local pathLine = 'export PATH="$HOME/.lpm:$HOME/.lpm/tools:$PATH"'

		-- Find a file that already has an lpm PATH entry and needs updating,
		-- or the first rc file that exists (to append to).
		local target = nil
		for _, rc in ipairs(rcFiles) do
			if fs.exists(rc) then
				local content = fs.read(rc) or ""
				if content:find("%.lpm", 1, true) then
					-- Already has some lpm entry — check if tools is missing
					if not content:find("%.lpm/tools", 1, true) then
						-- Replace the existing lpm PATH line with the full one
						local updated = content:gsub('export PATH="[^"]*%.lpm[^"]*"', pathLine)
						if updated == content then
							-- Line format didn't match the pattern; just append
							updated = content .. "\n" .. pathLine .. "\n"
						end
						fs.write(rc, updated)
						ansi.printf("{green}Updated PATH in %s", rc)
					else
						ansi.printf("{green}PATH is already up to date in %s", rc)
					end
					return
				end
				if not target then target = rc end
			end
		end

		-- No file had an lpm entry yet — append to the first existing rc
		if target then
			local content = fs.read(target) or ""
			fs.write(target, content .. "\n# Added by lpm\n" .. pathLine .. "\n")
			ansi.printf("{green}Added PATH entry to %s", target)
		else
			ansi.printf("{yellow}Could not find a shell rc file to update.")
			ansi.printf("{white}Add this line manually:  %s", pathLine)
		end
		ansi.printf("{yellow}Restart your shell or run: source <rc-file>")
	end

	return
end

local commands = {}
commands.help = require("lpm.commands.help")
commands.init = require("lpm.commands.initialize")
commands.new = require("lpm.commands.new")
commands.upgrade = require("lpm.commands.upgrade")
commands.add = require("lpm.commands.add")
commands.remove = require("lpm.commands.remove")
commands.run = require("lpm.commands.run")
commands.x = require("lpm.commands.x")
commands.install = require("lpm.commands.install")
commands.i = commands.install
commands.bundle = require("lpm.commands.bundle")
commands.compile = require("lpm.commands.compile")
commands.test = require("lpm.commands.test")
commands.tree = require("lpm.commands.tree")
commands.update = require("lpm.commands.update")
commands.uninstall = require("lpm.commands.uninstall")

local ok, err = xpcall(function()
	if args:count() == 0 then
		commands.help(args)
	else
		local commandName = args:pop()
		local commandHandler = commands[commandName]

		if commandHandler then
			commandHandler(args)
		else
			ansi.printf("{red}Unknown command: %s", tostring(commandName))
		end
	end
end, function(err)
	return { msg = err, trace = debug.traceback(err, 2) }
end)

if not ok then ---@cast err { msg: string, trace: string }
	ansi.printf("{red}Error: %s", tostring(err.msg))

	if env.var("DEBUG") then
		print(err.trace)
	end
end
