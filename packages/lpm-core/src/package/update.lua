local fs = require("fs")
local process = require("process")

local global = require("lpm-core.global")

--- Updates a single git dependency by pulling latest changes.
--- Only applies to git dependencies without a pinned commit.
---@param name string
---@param depInfo lpm.Config.Dependency
---@return boolean updated
---@return string message
local function updateDependency(name, depInfo)
	if not depInfo.git then
		return false, "skipped (not a git dependency)"
	end

	if depInfo.commit then
		return false, "skipped (pinned to commit)"
	end

	local repoDir = global.getGitRepoDir(name, depInfo.branch, depInfo.commit)
	if not fs.exists(repoDir) then
		return false, "skipped (not installed)"
	end

	local ok, output = process.exec("git", { "pull" }, { cwd = repoDir })
	if not ok then
		return false, "failed: " .. (output or "unknown error")
	end

	return true, (output or "updated"):gsub("%s+$", "")
end

--- Updates all git dependencies (without pinned commits) for a package.
---@param package lpm.Package
---@param dependencies table<string, lpm.Config.Dependency>?
---@return table<string, { updated: boolean, message: string }>
local function updateDependencies(package, dependencies)
	dependencies = dependencies or package:getDependencies()

	local results = {}
	for name, depInfo in pairs(dependencies) do
		local updated, message = updateDependency(name, depInfo)
		results[name] = { updated = updated, message = message }
	end

	return results
end

return updateDependencies
