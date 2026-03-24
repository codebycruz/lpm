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

---@param ref "HEAD" | string?
function git.revParse(ref)
	return process.exec("git", { "rev-parse", ref or "HEAD" })
end

---@param repoDir string?
function git.pull(repoDir)
	return process.exec("git", { "pull" }, { cwd = repoDir })
end

---@param repoDir string?
function git.init(repoDir)
	return process.exec("git", { "init" }, { cwd = repoDir })
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

return git
