local path = require("path")
local fs = require("fs")

local global = require("lpm-core.global")
local Lockfile = require("lpm-core.lockfile")
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
		local repoDir = global.getOrInitGitRepo(name, depInfo.git, depInfo.branch, depInfo.commit)

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

--- Merges lockfile pins into a git dependency's branch/commit if the
--- config doesn't explicitly specify them.
---@param depInfo lpm.Config.GitDependency
---@param lockEntry lpm.Lockfile.Raw.GitDependency?
---@return string? branch
---@return string? commit
local function resolveGitPins(depInfo, lockEntry)
	local branch = depInfo.branch
	local commit = depInfo.commit

	if lockEntry and not commit then
		commit = lockEntry.commit
		if not branch then
			branch = lockEntry.branch
		end
	end

	return branch, commit
end

---@param package lpm.Package
---@param dependencies table<string, lpm.Config.Dependency>?
---@param relativeTo string? # Directory to resolve relative paths from
local function installDependencies(package, dependencies, relativeTo)
	-- Only manage the lockfile for top-level calls (not recursive transitive installs)
	local isTopLevel = dependencies == nil
	dependencies = dependencies or package:getDependencies()
	relativeTo = relativeTo or package.dir

	local modulesDir = package:getModulesDir()
	if not fs.exists(modulesDir) then
		fs.mkdir(modulesDir)
	end

	-- Read existing lockfile if this is a top-level install
	local lockfile = nil ---@type lpm.Lockfile?
	local lockDeps = nil ---@type table<string, lpm.Lockfile.Raw.Dependency>?
	if isTopLevel then
		local lockfilePath = package:getLockfilePath()
		if fs.exists(lockfilePath) then
			lockfile = Lockfile.open(lockfilePath)
			lockDeps = lockfile:getDependencies()
		end
	end

	-- Track resolved git repo dirs for lockfile writing
	local gitRepoDirs = {} ---@type table<string, { git: string, repoDir: string }>

	for name, depInfo in pairs(dependencies) do
		local destinationPath = path.join(modulesDir, name)
		if fs.exists(destinationPath) then
			-- Already installed — still track for lockfile
			if depInfo.git then
				local repoDir = global.getGitRepoDir(name, depInfo.branch, depInfo.commit)
				if fs.exists(repoDir) then
					gitRepoDirs[name] = { git = depInfo.git, repoDir = repoDir }
				elseif lockDeps and lockDeps[name] and lockDeps[name].git then
					-- Resolve using lockfile pins
					local lockEntry = lockDeps[name] --[[@as lpm.Lockfile.Raw.GitDependency]]
					local branch, commit = resolveGitPins(depInfo --[[@as lpm.Config.GitDependency]], lockEntry)
					repoDir = global.getGitRepoDir(name, branch, commit)
					if fs.exists(repoDir) then
						gitRepoDirs[name] = { git = depInfo.git, repoDir = repoDir }
					end
				end
			end
			goto skip
		end

		-- Apply lockfile pins for git deps without explicit commit
		if depInfo.git and lockDeps then ---@cast depInfo lpm.Config.GitDependency
			local lockEntry = lockDeps[name]
			if lockEntry and lockEntry.git then ---@cast lockEntry lpm.Lockfile.Raw.GitDependency
				local branch, commit = resolveGitPins(depInfo, lockEntry)
				depInfo = { git = depInfo.git, branch = branch, commit = commit }
			end
		end

		if depInfo.git then
			gitRepoDirs[name] = {
				git = depInfo.git,
				repoDir = global.getGitRepoDir(name, depInfo.branch, depInfo.commit),
			}
		end

		local dependencyPackage = dependencyToPackage(name, depInfo, relativeTo)
		installDependency(package, dependencyPackage)

		::skip::
	end

	-- Write lockfile after top-level install
	if isTopLevel then
		local lockEntries = {}

		for name, info in pairs(gitRepoDirs) do
			lockEntries[name] = {
				git = info.git,
				commit = global.getGitCommit(info.repoDir),
				branch = global.getGitBranch(info.repoDir),
			}
		end

		Lockfile.new(package:getLockfilePath(), lockEntries):save()
	end
end

return installDependencies
