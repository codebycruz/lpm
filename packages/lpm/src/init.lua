-- Bootstrapping mode for initial creation of an lpm binary for a platform.
-- Heavily unoptimized, do not use this.
if os.getenv("BOOTSTRAP") then
	local scriptPath = debug.getinfo(1, "S").source:sub(2)
	local srcDir = scriptPath:match("^(.*)[/\\]")
	local baseDir = srcDir:match("^(.*)[/\\]")

	table.insert(package.loaders, 2, function(modname)
		if modname:match("^lpm%.") then
			local file = modname:gsub("^lpm%.", ""):gsub("%.", "/")

			local path = srcDir .. "/" .. file .. ".lua"
			if io.open(path, "r") then
				return loadfile(path)
			end

			path = srcDir .. "/" .. file .. "/init.lua"
			if io.open(path, "r") then
				return loadfile(path)
			end
		end
	end)

	package.path = baseDir .. "/lpm_modules/?.lua;" ..
		baseDir .. "/lpm_modules/?/init.lua;" ..
		package.path

	local separator = package.config:sub(1, 1)

	local function join(...)
		return table.concat({ ... }, separator)
	end

	local isWindows = separator == '\\'
	local lpmModulesDir = join(baseDir, "lpm_modules")

	local function dirExists(path)
		if isWindows then
			local result = os.execute('if exist "' .. path .. '" exit 0')
			return result == 0
		else
			local result = os.execute('test -d "' .. path .. '"')
			return result == 0
		end
	end

	if not dirExists(lpmModulesDir) then
		if isWindows then
			os.execute('mkdir "' .. lpmModulesDir .. '"')
		else
			os.execute('mkdir -p "' .. lpmModulesDir .. '"')
		end
	end

	local pathPackages = {
		"ansi", "clap", "fs", "http", "lockfile",
		"path", "process", "sea", "semver", "util"
	}

	for _, pkg in ipairs(pathPackages) do
		-- Semantics of the 'src' differ between windows and linux symlinks
		local relSrcPath = join("..", "..", pkg, "src")
		local absSrcPath = join(baseDir, "..", pkg, "src")

		local linkPath = join(lpmModulesDir, pkg)

		if not dirExists(linkPath) then
			if isWindows then
				os.execute('mklink /J "' .. linkPath .. '" "' .. absSrcPath .. '"')
			else
				os.execute("ln -sf '" .. relSrcPath .. "' '" .. linkPath .. "'")
			end
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

		if not dirExists(linkPath) then
			if isWindows then
				os.execute('git clone "' .. pkg.url .. '" "' .. tmpGitPath .. '"')
				os.execute('mklink /J "' .. linkPath .. '" "' .. join(tmpGitPath, "src") .. '"')
			else
				os.execute('git clone "' .. pkg.url .. '" "' .. tmpGitPath .. '"')
				os.execute("ln -sf '" .. join(tmpGitPath, "src") .. "' '" .. linkPath .. "'")
			end
		end
	end
end

local ansi = require("ansi")
local clap = require("clap")

local global = require("lpm.global")
global.init()

local args = clap.parse({ ... })

if args:has("version") then
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

if args:count() == 0 then
	commands.help()
else
	local command = args:pop("string")
	if commands[command] then
		commands[command](args)
	else
		print(ansi.colorize(ansi.red, "Unknown command: " .. tostring(command)))
	end
end
