local fs = require("fs")
local path = require("path")
local git2 = require("git2-sys")
local lde = require("lde-core")

---@param packageName string
---@param depInfo lde.Package.Config.GitDependency
---@return lde.Package, lde.Lockfile.GitDependency
local function resolve(packageName, depInfo)
	local repoDir = lde.global.getOrInitGitRepo(packageName, depInfo.git, depInfo.branch, depInfo.commit)

	local resolvedCommit = depInfo.commit
	if not resolvedCommit then
		local repo, openErr = git2.open(repoDir)
		if not repo then
			error("Failed to resolve HEAD commit for git dependency: " .. (openErr or ""))
		end
		local sha, revErr = repo:revparse("HEAD")
		if not sha then
			error("Failed to resolve HEAD commit for git dependency: " .. (revErr or ""))
		end
		resolvedCommit = sha
	end

	---@type lde.Lockfile.GitDependency
	local lockEntry = {
		git = depInfo.git,
		commit = resolvedCommit,
		branch = depInfo.branch,
		name = depInfo.name,
		rockspec = depInfo.rockspec,
	}

	local function findPkg(dir)
		local pkg = lde.Package.open(dir, depInfo.rockspec)
		if pkg and pkg:getName() == packageName then return pkg end

		for _, config in ipairs(fs.scan(dir, "**" .. path.separator .. "lde.json")) do
			pkg = lde.Package.open(path.join(dir, path.dirname(config)))
			if pkg and pkg:getName() == packageName then return pkg end
		end

		-- Compatibility
		for _, config in ipairs(fs.scan(dir, "**" .. path.separator .. "lpm.json")) do
			pkg = lde.Package.open(path.join(dir, path.dirname(config)))
			if pkg and pkg:getName() == packageName then return pkg end
		end
	end

	local pkg = findPkg(repoDir)
	if not pkg then
		error("No lde.json with name '" .. packageName .. "' found in git repository")
	end

	return pkg, lockEntry
end

return resolve
