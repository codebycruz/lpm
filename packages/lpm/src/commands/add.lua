local json = require("json")
local ansi = require("ansi")
local fs = require("fs")

local Package = require("lpm.package")

---@param args clap.Args
local function add(args)
	local name = assert(args:pop("string"), "Usage: lpm add <name> --path <path> | --git <url>")

	local depType, depValue
	if args:has("git") then
		depType = "git"
		depValue = args:key("git", "string")
	elseif args:has("path") then
		depType = "path"
		depValue = args:key("path", "string")
	end

	if not depType then
		print(ansi.colorize(ansi.red, "You must specify either --path <path> or --git <url>"))
		return
	end

	local p = Package.open()
	local configPath = p:getConfigPath()

	local config = json.decode(fs.read(p:getConfigPath()))
	if not config.dependencies then
		config.dependencies = {}
	end

	if config.dependencies[name] then
		print(ansi.colorize(ansi.yellow, "Dependency already exists: " .. name))
		return
	end

	config.dependencies[name] = { [depType] = depValue }

	local file = io.open(configPath, "w")
	if file then
		file:write(json.encode(config))
		file:close()
		print(ansi.colorize(ansi.green, "Added dependency: " .. name) ..
			" (" .. ansi.colorize(ansi.cyan, depType .. ": " .. depValue) .. ")")
	end
end

return add
