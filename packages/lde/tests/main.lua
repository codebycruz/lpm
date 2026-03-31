local test = require("lde-test")

local process = require("process")
local fs = require("fs")
local env = require("env")
local path = require("path")
local json = require("json")
local git = require("git")

local lde = require("lde-core")

local ldePath = assert(env.execPath())

---@param args string[]
local function ldecli(args)
	return process.exec(ldePath, args)
end

test.it("should do that", function()
	local ok, out = ldecli { "--version" }
end)

-- Regression test for: lde x no longer respects --git (#95)
-- `lde x triangle --git <url>` was failing with "Package 'triangle' not found in lde registry"
-- because the alias name was consumed as a sub-package name instead of being ignored.
test.it("lde x: alias name before --git does not cause registry lookup", function()
	-- Pre-populate the git cache so no real clone happens
	local repoDir = lde.global.getGitRepoDir("hood")
	fs.rmdir(repoDir)
	fs.mkdir(repoDir)
	git.init(repoDir, true)
	fs.write(path.join(repoDir, "lde.json"), json.encode({
		name = "hood",
		version = "1.0.0",
		dependencies = {}
	}))
	fs.mkdir(path.join(repoDir, "src"))
	fs.write(path.join(repoDir, "src", "init.lua"), "")

	local ok, out = ldecli { "x", "triangle", "--git", "https://github.com/codebycruz/hood" }
	test.falsy(out and out:find("not found in lde registry"), out)

	fs.rmdir(repoDir)
end)
