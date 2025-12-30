local ansi = require("ansi")
local fs = require("fs")
local sea = require("sea")

local Project = require("lpm.project")

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

local function scanDependencies(projectDir)
	local files = {}
	local lpmModulesDir = projectDir .. "/lpm_modules"

	if not fs.exists(lpmModulesDir) then
		return files
	end

	local handle = io.popen("find '" .. lpmModulesDir .. "' -maxdepth 1 -mindepth 1 -type d 2>/dev/null")
	if not handle then
		return files
	end

	for depDir in handle:lines() do
		local depName = fs.basename(depDir)
		local depFiles = scanProjectSrc(depName, depDir)
		for _, depFile in ipairs(depFiles) do
			table.insert(files, depFile)
		end
	end
	handle:close()

	return files
end

---@param args clap.Args
local function bundle(args)
	local outfile = args:pop("string")

	local p = Project.openCwd()
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

	local depFiles = scanDependencies(p.dir)
	for _, depFile in ipairs(depFiles) do
		table.insert(files, depFile)
	end

	if #depFiles > 0 then
		print(ansi.colorize(ansi.cyan, "Including " .. #depFiles .. " dependency files in bundle"))
	end

	local executable = sea.compile(p.config.name, files)

	if outfile then
		fs.copy(executable, outfile)
		os.execute("rm " .. executable)
		print(ansi.colorize(ansi.green, "Bundle created: " .. outfile))
	else
		print(ansi.colorize(ansi.green, "Bundle created: " .. executable))
	end
end

return bundle
