local script_path = debug.getinfo(1, "S").source:sub(2)
local src_dir = script_path:match("^(.*)[/\\]")
local base_dir = src_dir:match("^(.*)[/\\]")

-- Insert custom loader for lpm.* -> src/*
table.insert(package.loaders, 2, function(modname)
	if modname:match("^lpm%.") then
		local file = modname:gsub("^lpm%.", ""):gsub("%.", "/")
		local path = src_dir .. "/" .. file .. ".lua"
		local f = io.open(path, "r")
		if f then
			f:close()
			return loadfile(path)
		end

		-- Try init.lua pattern
		path = src_dir .. "/" .. file .. "/init.lua"
		f = io.open(path, "r")
		if f then
			f:close()
			return loadfile(path)
		end
	end
	return "\n\tno custom loader match"
end)

-- Keep lpm_modules in package.path
package.path = base_dir .. "/lpm_modules/?.lua;" ..
	base_dir .. "/lpm_modules/?/init.lua;" ..
	package.path

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
