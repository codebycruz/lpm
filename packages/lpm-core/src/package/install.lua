local path = require("path")
local fs = require("fs")

local global = require("lpm-core.global")
local Package = require("lpm-core.package")

---@param package lpm.Package
---@param dependency lpm.Package
---@param alias string # The name to install under (may differ from dependency:getName() when aliasing)
local function installDependency(package, dependency, alias)
	-- Recursively install dependencies of the dependency first
	package:installDependencies(dependency:getDependencies(), dependency:getDir())

	local modulesDir = package:getModulesDir()
	local destinationPath = path.join(modulesDir, alias)
	if fs.islink(destinationPath) then
		-- If its a symlink it should already be at the latest version.
		return
	end

	-- Otherwise, always assume it is dirty and needs to be updated.
	-- In the future this could potentially do a modification diff.
	dependency:build(destinationPath)
end

--- Gets a proper lpm.Package instance from dependency info.
--- For git dependencies, this will clone it to the global git cache.
--- For path dependencies, this will resolve the path and load the package from there.
---@param alias string # The key in the dependencies table (used as the install name)
---@param depInfo lpm.Config.Dependency
---@param relativeTo string
local function dependencyToPackage(alias, depInfo, relativeTo)
	-- depInfo.package overrides the lookup name (aliasing support)
	local packageName = depInfo.package or alias

	if depInfo.git then
		local repoDir = global.getOrInitGitRepo(packageName, depInfo.git, depInfo.branch, depInfo.commit)

		local gitDependencyPackage = Package.open(repoDir)
		if gitDependencyPackage and gitDependencyPackage:getName() == packageName then
			return gitDependencyPackage
		end

		for _, config in ipairs(fs.scan(repoDir, "**" .. path.separator .. "lpm.json")) do
			local parentDir = path.join(repoDir, path.dirname(config))

			gitDependencyPackage = Package.open(parentDir)
			if gitDependencyPackage and gitDependencyPackage:getName() == packageName then
				return gitDependencyPackage
			end
		end

		error("No lpm.json with name '" .. packageName .. "' found in git repository")
	elseif depInfo.path then
		local normalized = path.normalize(depInfo.path)
		local localPackage, err = Package.open(path.resolve(relativeTo, normalized))

		if not localPackage then
			error("Failed to load local dependency package for: " .. alias .. "\nError: " .. err)
		end

		return localPackage
	else
		error("Unsupported dependency type for: " .. alias)
	end
end

---@param package lpm.Package
---@param dependencies table<string, lpm.Config.Dependency>?
---@param relativeTo string? # Directory to resolve relative paths from
local function installDependencies(package, dependencies, relativeTo)
	dependencies = dependencies or package:getDependencies()
	relativeTo = relativeTo or package.dir

	local modulesDir = package:getModulesDir()
	if not fs.exists(modulesDir) then
		fs.mkdir(modulesDir)
	end

	for name, depInfo in pairs(dependencies) do
		local dependencyPackage = dependencyToPackage(name, depInfo, relativeTo)
		installDependency(package, dependencyPackage, name)
	end
end

return installDependencies
