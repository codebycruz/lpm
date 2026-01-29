-- Bootstrapping mode for initial creation of an lpm binary for a platform.
-- Heavily unoptimized, do not use this.
if os.getenv("BOOTSTRAP") then
	local scriptPath = debug.getinfo(1, "S").source:sub(2)
	local srcDir = scriptPath:match("^(.*)[/\\]")
	local baseDir = srcDir:match("^(.*)[/\\]")

	package.path = baseDir .. "/lpm_modules/?.lua;" ..
		baseDir .. "/lpm_modules/?/init.lua;" ..
		package.path

	local separator = package.config:sub(1, 1)

	local function join(...)
		return table.concat({ ... }, separator)
	end

	local isWindows = separator == '\\'
	local lpmModulesDir = join(baseDir, "lpm_modules")

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
		"ansi", "clap", "fs", "http", "env", "path",
		"process", "sea", "semver", "util", "lpm-core"
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

	local function tmp()
		if isWindows then
			return os.getenv("TEMP") or "C:\\Temp"
		else
			return "/tmp"
		end
	end

	local gitPackages = {
		{ name = "json", url = "https://github.com/codebycruz/json.lua.git" }
	}

	for _, pkg in ipairs(gitPackages) do
		local linkPath = join(lpmModulesDir, pkg.name)
		local tmpGitPath = join(tmp(), "lpm_bootstrap_" .. pkg.name)

		if not exists(tmpGitPath) then
			os.execute('git clone "' .. pkg.url .. '" "' .. tmpGitPath .. '"')
		end

		if not exists(linkPath) then
			if isWindows then
				os.execute('mklink /J "' .. linkPath .. '" "' .. join(tmpGitPath, "src") .. '"')
			else
				os.execute("ln -sf '" .. join(tmpGitPath, "src") .. "' '" .. linkPath .. "'")
			end
		end
	end
end

local ansi = require("ansi")
local clap = require("clap")

local global = require("lpm-core.global")
global.init()

local args = clap.parse({ ... })

if args:flag("version") and args:count() == 0 then
	print(global.currentVersion)
	return
end

local commands = {}
commands.help = require("lpm.commands.help")
commands.init = require("lpm.commands.init")
commands.new = require("lpm.commands.new")
commands.upgrade = require("lpm.commands.upgrade")
commands.add = require("lpm.commands.add")
commands.run = require("lpm.commands.run")
commands.install = require("lpm.commands.install")
commands.i = commands.install
commands.bundle = require("lpm.commands.bundle")
commands.compile = require("lpm.commands.compile")
commands.test = require("lpm.commands.test")
commands.tree = require("lpm.commands.tree")

local ok, err = xpcall(function()
	if args:count() == 0 then
		commands.help()
	else
		local command = args:pop("string")
		if commands[command] then
			commands[command](args)
		else
			ansi.printf("{red}Unknown command: %s", tostring(command))
		end
	end
end, function(err)
	return { msg = err, trace = debug.traceback(err, 2) }
end)

if not ok then ---@cast err { msg: string, trace: string }
	ansi.printf("{red}Error: %s", tostring(err.msg))

	if os.getenv("DEBUG") then
		print(err.trace)
	end
end
