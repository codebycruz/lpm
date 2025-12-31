local ansi = require("ansi")
local fs = require("fs")
local sea = require("sea")

local Package = require("lpm.package")

local function scanProjectSrc(projectName, srcDir)
	local files = {}

	for _, filePath in ipairs(fs.scan(srcDir, "**/*.lua")) do
		local moduleName

		if filePath == "init.lua" then
			moduleName = projectName
		else
			moduleName = projectName .. "." .. filePath:gsub(fs.separator, "."):gsub("%.lua$", "")
		end

		if moduleName ~= "" then
			local content = fs.read(filePath)
			if content then
				table.insert(files, {
					path = moduleName,
					content = content
				})
			else
				print(ansi.colorize(ansi.yellow, "Warning: Could not read file: " .. filePath))
			end
		end
	end

	return files
end

local function scanDependencies(projectDir)
	local files = {}
	local lpmModulesDir = projectDir .. "/lpm_modules"

	if not fs.exists(lpmModulesDir) then
		return files
	end

	for _, depDir in ipairs(fs.listdir(lpmModulesDir)) do
		local depName = fs.basename(depDir)
		local depFiles = scanProjectSrc(depName, depDir)

		for _, depFile in ipairs(depFiles) do
			files[#files + 1] = depFile
		end
	end

	return files
end

---@param args clap.Args
local function bundle(args)
	local outFile = args:key("outfile", "string")
	if not outFile then
		error("Please specify an output file using --outfile")
	end

	local p = Package.open()

	local packageName = p:getName()
	if not packageName then
		error("Package must have a name in lpm.json")
	end

	local srcDir = p.dir .. "/src"
	if not fs.exists(srcDir) then
		error("Project must have a src directory")
	end

	local initFile = srcDir .. "/init.lua"
	if not fs.exists(initFile) then
		error("Project src directory must contain init.lua")
	end

	local files = scanProjectSrc(packageName, srcDir)

	if #files == 0 then
		error("No Lua files found in src directory")
	end

	local depFiles = scanDependencies(p.dir)
	for _, depFile in ipairs(depFiles) do
		files[#files + 1] = depFile
	end

	if #depFiles > 0 then
		print(ansi.colorize(ansi.cyan, "Including " .. #depFiles .. " dependency files in bundle"))
	end

	local executable = sea.compile(packageName, files)

	fs.copy(executable, outFile)
	os.execute("rm " .. executable)
	print(ansi.colorize(ansi.green, "Bundle created: " .. outFile))
end

return bundle
