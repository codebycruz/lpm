local json = require("json")
local ansi = require("ansi")
local fs = require("fs")

local Package = require("lpm-core.package")

---@param args clap.Args
local function add(args)
	local name = assert(args:pop("string"), "Usage: lpm add <name> --path <path> | --git <url>")
	local isDevelopment = args:flag("dev")

	---@type ("git" | "path")?, string?
	local depType, depValue
	if args:option("git", "string") then
		depType = "git"
		depValue = args:option("git", "string")
	elseif args:option("path", "string") then
		depType = "path"
		depValue = args:option("path", "string")
	end

	if not depType or not depValue then
		ansi.printf("{red}You must specify either --path <path> or --git <url>")
		return
	end

	local p = Package.open()
	local configPath = p:getConfigPath()

	---@type lpm.Config
	local config = json.decode(fs.read(p:getConfigPath()))

	local dependencyTable ---@type lpm.Config.Dependencies
	if isDevelopment then
		if not config.devDependencies then
			config.devDependencies = {}
		end

		dependencyTable = config.devDependencies
	else
		if not config.dependencies then
			config.dependencies = {}
		end
		dependencyTable = config.dependencies
	end ---@cast dependencyTable -nil

	if dependencyTable[name] then
		ansi.printf("{yellow}Dependency already exists: %s", name)
		return
	end

	if depType == "path" then
		dependencyTable[name] = { path = depValue }
	elseif depType == "git" then
		local branch = args:option("branch", "string")
		local commit = args:option("commit", "string")

		dependencyTable[name] = { git = depValue, branch = branch, commit = commit }
	end

	fs.write(configPath, json.encode(config))
	ansi.printf("{green}Added dependency: %s{reset} ({cyan}%s: %s{reset})", name, depType, depValue)
end

return add
