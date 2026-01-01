if os.getenv("BOOTSTRAP") then
	local scriptPath = debug.getinfo(1, "S").source:sub(2)
	local srcDir = scriptPath:match("^(.*)[/\\]")
	local baseDir = srcDir:match("^(.*)[/\\]")

	-- Insert custom loader for lpm.* -> src/*
	table.insert(package.loaders, 2, function(modname)
		if modname:match("^lpm%.") then
			local file = modname:gsub("^lpm%.", ""):gsub("%.", "/")

			-- Try regular .lua file
			local path = srcDir .. "/" .. file .. ".lua"
			if io.open(path, "r") then
				return loadfile(path)
			end

			-- Try init.lua pattern
			path = srcDir .. "/" .. file .. "/init.lua"
			if io.open(path, "r") then
				return loadfile(path)
			end
		end
	end)

	-- Add lpm_modules to package.path
	package.path = baseDir .. "/lpm_modules/?.lua;" ..
		baseDir .. "/lpm_modules/?/init.lua;" ..
		package.path
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
