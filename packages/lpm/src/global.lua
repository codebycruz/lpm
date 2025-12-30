local global = {}

local path = require("path")

function global.getDir()
	local home = os.getenv("HOME") or os.getenv("USERPROFILE")
	return path.join(home, ".lpm")
end

function global.getGitCacheDir()
	return path.join(global.getDir(), "git")
end

return global
