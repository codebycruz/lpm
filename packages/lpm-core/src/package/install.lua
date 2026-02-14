local path = require("path")
local fs = require("fs")

local global = require("lpm-core.global")
local Package = require("lpm-core.package")

---@param package lpm.Package
---@param dependency lpm.Package
local function installDependency(package, dependency)
	-- Recursively install dependencies of the dependency first
	package:installDependencies(dependency:getDependencies(), dependency:getDir())

	local modulesDir = package:getModulesDir()
	local destinationPath = path.join(modulesDir, dependency:getName())
	if fs.exists(destinationPath) then
		return
	end

	dependency:build(destinationPath)
end

--- Gets a proper lpm.Package instance from dependency info.
--- For git dependencies, this will clone it to the global git cache.
--- For path dependencies, this will resolve the path and load the package from there.
---@param name string
---@param depInfo lpm.Config.Dependency
---@param relativeTo string
local function dependencyToPackage(name, depInfo, relativeTo)
	if depInfo.git then
		local repoDir = global.getOrInitGitRepo(name, depInfo.git)

		for _, config in ipairs(fs.scan(repoDir, "**" .. path.separator .. "lpm.json")) do
			local parentDir = path.join(repoDir, path.dirname(config))

			local gitDependencyPackage, err = Package.open(parentDir)
			if not gitDependencyPackage then
				error("Failed to load git dependency package for: " .. name .. "\nError: " .. err)
			end

			return gitDependencyPackage
		end

		error("No lpm.json found in git repository for dependency: " .. name)
	elseif depInfo.path then
		local normalized = path.normalize(depInfo.path)
		local localPackage, err = Package.open(path.resolve(relativeTo, normalized))

		if not localPackage then
			error("Failed to load local dependency package for: " .. name .. "\nError: " .. err)
		end

		return localPackage
	else
		error("Unsupported dependency type for: " .. name)
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
		local destinationPath = path.join(modulesDir, name)
		if fs.exists(destinationPath) then
			-- TODO: replace with update logic..
			goto skip
		end

		local dependencyPackage = dependencyToPackage(name, depInfo, relativeTo)
		installDependency(package, dependencyPackage)

		::skip::
	end
end

return installDependencies
