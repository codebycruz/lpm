local process = require("process")

local git = {}

---@param url string
---@param dir string
---@param branch string?
---@param commit string?
function git.clone(url, dir, branch, commit)
	local args = { "clone", url, dir }

	if branch then
		args[#args + 1] = "-b"
		args[#args + 1] = branch
	end

	if commit then
		args[#args + 1] = "--commit"
		args[#args + 1] = commit
	end

	return process.exec("git", args)
end

---@param cwd string?
---@param ref "HEAD" | string?
function git.revParse(cwd, ref)
	return process.exec("git", { "rev-parse", ref or "HEAD" }, { cwd = cwd })
end

---@param repoDir string?
function git.pull(repoDir)
	return process.exec("git", { "pull" }, { cwd = repoDir })
end

---@param dir string?
---@param bare boolean?
function git.init(dir, bare)
	local args = { "init" }
	if bare then
		args[#args + 1] = "--bare"
	end
	return process.exec("git", args, { cwd = dir })
end

---@param commit string
---@param repoDir string?
function git.checkout(commit, repoDir)
	return process.exec("git", { "checkout", commit }, { cwd = repoDir })
end

function git.version()
	return process.exec("git", { "--version" })
end

---@param dir string?
function git.isInsideWorkTree(dir)
	return process.exec("git", { "rev-parse", "--is-inside-work-tree" }, { cwd = dir })
end

---@param remoteName string
---@param cwd string?
function git.remoteGetUrl(remoteName, cwd)
	return process.exec("git", { "remote", "get-url", remoteName }, { cwd = cwd })
end

---@param cwd string?
function git.getCurrentBranch(cwd)
	return process.exec("git", { "rev-parse", "--abbrev-ref", "HEAD" }, { cwd = cwd })
end

return git
