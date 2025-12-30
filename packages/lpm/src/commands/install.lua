local fs = require("fs")
local ansi = require("ansi")
local json = require("json")

local Package = require("lpm.package")

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
		local depSrcPath = resolvedPath .. "/src"

		if not fs.exists(destPath) then
			fs.mkdir(destPath)
			if fs.exists(depSrcPath) then
				os.execute("cp -r " .. depSrcPath .. "/* " .. destPath .. "/ 2>/dev/null")
				print(ansi.colorize(ansi.green, "Installed dependency: " .. depName) ..
					" from " .. ansi.colorize(ansi.cyan, resolvedPath))
			else
				error("Dependency " .. depName .. " has no src directory")
			end
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

		local runtimePath = "./lpm_modules/?.lua"
		local runtimeInitPath = "./lpm_modules/?/init.lua"

		local foundRuntime = false
		local foundRuntimeInit = false
		for _, path in ipairs(luarcConfig["runtime"]["path"]) do
			if path == runtimePath then
				foundRuntime = true
			end
			if path == runtimeInitPath then
				foundRuntimeInit = true
			end
		end

		if not foundRuntime then
			table.insert(luarcConfig["runtime"]["path"], runtimePath)
		end
		if not foundRuntimeInit then
			table.insert(luarcConfig["runtime"]["path"], runtimeInitPath)
		end

		local depPackage = Package.openPath(resolvedPath)
		if depPackage.config.dependencies then
			for subDepName, subDep in pairs(depPackage.config.dependencies) do
				installDependency(rootDir, subDepName, subDep, luarcConfig, installed, resolvedPath)
			end
		end
	else
		print(ansi.colorize(ansi.red, "Unsupported dependency type for: " .. depName))
	end
end

---@param args clap.Args
local function install(args)
	local p = Package.openCwd()
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

	if not luarcConfig["runtime"] then
		luarcConfig["runtime"] = {}
	end
	if not luarcConfig["runtime"]["path"] then
		luarcConfig["runtime"]["path"] = {}
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

return install
