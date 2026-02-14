local sea = require("sea")
local fs = require("fs")
local path = require("path")

---@param package lpm.Package
local function compilePackage(package)
	package:build()
	package:installDependencies()

	---@type table<{path: string, content: string}>
	local files = {}

	---@param dir string
	local function bundleDir(projectName, dir)
		for _, relativePath in ipairs(fs.scan(dir, "**" .. path.separator .. "*.lua")) do
			local absPath = path.join(dir, relativePath)
			local content = fs.read(absPath)
			if not content then
				error("Could not read file: " .. absPath)
			end

			-- Map file paths to Lua module names following the init.lua convention:
			-- init.lua -> projectName, foo/init.lua -> projectName.foo, etc.
			local moduleName = relativePath:gsub(path.separator, "."):gsub("%.lua$", ""):gsub("%.?init$", "")
			if moduleName ~= "" then
				moduleName = projectName .. "." .. moduleName
			else
				moduleName = projectName
			end

			table.insert(files, { path = moduleName, content = content })
		end
	end

	local modulesDir = package:getModulesDir()
	bundleDir(package:getName(), path.join(modulesDir, package:getName()))

	-- Use the lpm_modules directory for the build artifacts rather than src,
	-- since build scripts may modify src contents.
	for depName in pairs(package:getDependencies()) do
		local buildFolder = path.join(modulesDir, depName)
		bundleDir(depName, buildFolder)
	end

	return sea.compile(package:getName(), files)
end

return compilePackage
