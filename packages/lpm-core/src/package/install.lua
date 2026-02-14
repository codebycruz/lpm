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
			goto skip
		end

		if depInfo.git then
			local repoDir = global.getOrInitGitRepo(name, depInfo.git)

			for _, config in ipairs(fs.scan(repoDir, "**" .. path.separator .. "lpm.json")) do
				local parentDir = path.join(repoDir, path.dirname(config))
				local gitDependencyPackage = Package.open(parentDir)

				if gitDependencyPackage:getName() == name then
					installDependency(package, gitDependencyPackage)
				end
			end
		elseif depInfo.path then
			local normalized = path.normalize(depInfo.path)
			local localPackage = Package.open(path.resolve(relativeTo, normalized))

			installDependency(package, localPackage)
		else
			error("Unsupported dependency type for: " .. name)
		end

		::skip::
	end
end

return installDependencies
