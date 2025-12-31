local ansi = require("ansi")
local clap = require("clap")

local global = require("lpm.global")
global.init()

local args = clap.parse({ ... })

local commands = {}
commands.help = require("lpm.commands.help")
commands.init = require("lpm.commands.init")
commands.new = require("lpm.commands.new")
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
