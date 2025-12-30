#!/usr/bin/env lua

local fs = require("lpm.fs")
local json = require("lpm.json")
local ansi = require("lpm.ansi")
local bundle = require("lpm.bundle")

local Project = require("lpm.project")

local commands = {}

function commands.help()
	print("Available commands:")
	print("  " .. ansi.colorize(ansi.red, "new <name>") .. "      Create a new lpm project")
	print("  " .. ansi.colorize(ansi.red, "init") .. "            Initialize current directory as lpm project")
	print("  " .. ansi.colorize(ansi.orange, "add <name>") .. "       Add a dependency (--path <path> or --git <url>)")
	print("  " .. ansi.colorize(ansi.orange, "install (i)") .. "     Install project dependencies")
	print("  " .. ansi.colorize(ansi.green, "run <script>") .. "    Run a Lua script with dependencies")
	print("  " .. ansi.colorize(ansi.magenta, "bundle [outfile]") .. " Bundle current project into executable")
	print("  " .. ansi.colorize(ansi.blue, "help") .. "            Show this help message")
end

local function initProject(dir, name)
	local configPath = dir .. "/lpm.json"
	if fs.exists(configPath) then
		error("Directory already contains lpm.json")
	end

	local config = {
		name = name,
		version = "1.0.0",
		engine = "lua"
	}

	local file = io.open(configPath, "w")
	if file then
		file:write(json.encode(config))
		file:close()
		print(ansi.colorize(ansi.green, "Created lpm.json"))
	end

	local initPath = dir .. "/init.lua"
	if not fs.exists(initPath) then
		local file = io.open(initPath, "w")
		if file then
			file:write('print("Hello world!")\n')
			file:close()
			print(ansi.colorize(ansi.green, "Created init.lua"))
		end
	end
end

function commands.new(name)
	if not name then
		error("Usage: lpm new <name>")
	end

	if fs.exists(name) then
		error("Directory " .. name .. " already exists")
	end

	fs.mkdir(name)
	print(ansi.colorize(ansi.green, "Created directory: " .. name))
	initProject(name, name)
end

function commands.init()
	local cwd = "."
	local name = fs.basename(fs.cwd())
	initProject(cwd, name)
end

function commands.add(name, ...)
	if not name then
		error("Usage: lpm add <name> --path <path> | --git <url>")
	end

	local args = { ... }
	local depType, depValue

	for i = 1, #args do
		if args[i] == "--path" and args[i + 1] then
			depType = "path"
			depValue = args[i + 1]
			break
		elseif args[i] == "--git" and args[i + 1] then
			depType = "git"
			depValue = args[i + 1]
			break
		end
	end

	if not depType then
		error("Must specify either --path <path> or --git <url>")
	end

	local p = Project.fromCwd()
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

local function installDependency(rootDir, depName, dep, luarcConfig, installed, projectDir)
	if installed[depName] then
		return
	end
	installed[depName] = true

	if dep.path then
		local resolvedPath
		if dep.path:sub(1, 1) == "/" then
			resolvedPath = dep.path
		else
			resolvedPath = projectDir .. "/" .. dep.path
		end
		local depConfigPath = resolvedPath .. "/lpm.json"
		if not fs.exists(depConfigPath) then
			error("Dependency " .. depName .. " at " .. dep.path .. " is not an lpm module (missing lpm.json)")
		end

		local destPath = rootDir .. "/lpm_modules/" .. depName
		local libraryPath = "./lpm_modules/" .. depName

		if not fs.exists(destPath) then
			fs.mklink(resolvedPath, destPath)
			print(ansi.colorize(ansi.green, "Installed dependency: " .. depName) ..
				" from " .. ansi.colorize(ansi.cyan, resolvedPath))
		else
			print(ansi.colorize(ansi.yellow, "Dependency already installed: " .. depName))
		end

		local found = false
		for _, path in ipairs(luarcConfig["workspace.library"]) do
			if path == libraryPath then
				found = true
				break
			end
		end

		if not found then
			table.insert(luarcConfig["workspace.library"], libraryPath)
		end

		local depProject = Project.new(resolvedPath)
		if depProject.config.dependencies then
			for subDepName, subDep in pairs(depProject.config.dependencies) do
				installDependency(rootDir, subDepName, subDep, luarcConfig, installed, resolvedPath)
			end
		end
	else
		print(ansi.colorize(ansi.red, "Unsupported dependency type for: " .. depName))
	end
end

function commands.install()
	local p = Project.fromCwd()
	fs.mkdir(p.dir .. "/lpm_modules")

	local luarcPath = p.dir .. "/.luarc.json"
	local luarcConfig = {}

	if fs.exists(luarcPath) then
		local file = io.open(luarcPath, "r")
		if file then
			local content = file:read("*all")
			file:close()
			luarcConfig = json.decode(content)
		end
	end

	if not luarcConfig["workspace.library"] then
		luarcConfig["workspace.library"] = {}
	end

	local installed = {}
	if p.config.dependencies then
		for depName, dep in pairs(p.config.dependencies) do
			installDependency(p.dir, depName, dep, luarcConfig, installed, p.dir)
		end
	end

	local file = io.open(luarcPath, "w")
	if file then
		file:write(json.encode(luarcConfig))
		file:close()
		print(ansi.colorize(ansi.green, "Updated .luarc.json"))
	end
end

commands.i = commands.install

function commands.run(path)
	local p = Project.fromCwd()

	local lpmModulesPath = p.dir .. "/lpm_modules"
	local luaPath = lpmModulesPath .. "/?.lua;" .. lpmModulesPath .. "/?/init.lua;"

	local engine = p.config.engine or "lua"
	local cmd = string.format("LUA_PATH=%q %s %q", luaPath, engine, path)
	os.execute(cmd)
end

local function scanProjectSrc(projectName, srcDir)
	local files = {}

	local handle = io.popen("find '" .. srcDir .. "' -name '*.lua' -type f 2>/dev/null")
	if not handle then
		error("Failed to scan src directory: " .. srcDir)
	end

	for line in handle:lines() do
		local filePath = line:gsub("^" .. srcDir .. "/?", "")
		local moduleName

		if filePath == "init.lua" then
			moduleName = projectName
		else
			moduleName = projectName .. "." .. filePath:gsub("/", "."):gsub("%.lua$", "")
		end

		if moduleName ~= "" then
			local file = io.open(line, "r")
			if file then
				local content = file:read("*all")
				file:close()

				table.insert(files, {
					path = moduleName,
					content = content
				})
			else
				print(ansi.colorize(ansi.yellow, "Warning: Could not read file: " .. line))
			end
		end
	end
	handle:close()

	return files
end

function commands.bundle(outfile)
	local p = Project.fromCwd()

	if not p.config.name then
		error("Project must have a name in lpm.json")
	end

	local srcDir = p.dir .. "/src"
	if not fs.exists(srcDir) then
		error("Project must have a src directory")
	end

	local initFile = srcDir .. "/init.lua"
	if not fs.exists(initFile) then
		error("Project src directory must contain init.lua")
	end

	local files = scanProjectSrc(p.config.name, srcDir)

	if #files == 0 then
		error("No Lua files found in src directory")
	end

	local executable = bundle.compile(p.config.name, files)

	if outfile then
		fs.copy(executable, outfile)
		os.execute("rm " .. executable)
		print(ansi.colorize(ansi.green, "Bundle created: " .. outfile))
	else
		print(ansi.colorize(ansi.green, "Bundle created: " .. executable))
	end
end

local args = { ... }
local arg1 = args[1]

if commands[arg1] then
	local cmdArgs = {}
	for i = 2, #args do
		cmdArgs[i - 1] = args[i]
	end
	commands[arg1](table.unpack(cmdArgs))
else
	print(ansi.colorize(ansi.red, "Unknown command: " .. tostring(arg1)))
	commands["help"]()
end
