local json = require("json")
local ansi = require("ansi")

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
		error("You must specify either --path <path> or --git <url>")
	end

	local p = Package.open()
	local configPath = p.dir .. "/lpm.json"

	local file = io.open(configPath, "r")
	if not file then
		error("Could not read lpm.json")
	end

	local content = file:read("*all")
	file:close()

	local config = json.decode(content)

	if not config.dependencies then
		config.dependencies = {}
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
