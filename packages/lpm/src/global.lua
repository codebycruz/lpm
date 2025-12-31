local global = {}

local fs = require("fs")
local path = require("path")
local process = require("process")

global.currentVersion = "0.2.1"

function global.getDir()
	local home = os.getenv("HOME") or os.getenv("USERPROFILE")
	return path.join(home, ".lpm")
end

function global.getGitCacheDir()
	return path.join(global.getDir(), "git")
end

---@param repoName string
function global.getGitRepoDir(repoName)
	local safeName = repoName:gsub("[^%w_%-]", "_")
	return path.join(global.getGitCacheDir(), safeName)
end

---@param repoName string
---@param repoUrl string
function global.cloneDir(repoName, repoUrl)
	local repoDir = global.getGitRepoDir(repoName)
	return process.spawn("git", { "clone", repoUrl, repoDir })
end

---@param repoName string
---@param repoUrl string
function global.getOrInitGitRepo(repoName, repoUrl)
	local repoDir = global.getGitRepoDir(repoName)
	if not fs.exists(repoDir) then
		local ok, err = global.cloneDir(repoName, repoUrl)
		if not ok then
			error("Failed to clone git repository: " .. err)
		end
	end

	return repoDir
end

function global.init()
	local dir = global.getDir()
	if not fs.exists(dir) then
		fs.mkdir(dir)
	end

	local gitCacheDir = global.getGitCacheDir()
	if not fs.exists(gitCacheDir) then
		fs.mkdir(gitCacheDir)
	end
end

return global
