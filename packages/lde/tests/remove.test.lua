local test = require("lde-test")

local fs = require("fs")
local env = require("env")
local path = require("path")
local json = require("json")

local ldecli = require("tests.lib.ldecli")

local tmpBase = path.join(env.tmpdir(), "lde-remove-tests")
fs.rmdir(tmpBase)
fs.mkdir(tmpBase)

local function makeProject(name, deps)
	local dir = path.join(tmpBase, name)
	fs.mkdir(dir)
	fs.mkdir(path.join(dir, "src"))
	fs.write(path.join(dir, "src", "init.lua"), "")
	fs.write(path.join(dir, "lde.json"), json.encode({
		name = name,
		version = "0.1.0",
		dependencies = deps or {}
	}))
	return dir
end

test.it("lde remove removes the dep from lde.json", function()
	local dir = makeProject("remove-json-test", { mypkg = { path = "../mypkg" } })

	ldecli({ "remove", "mypkg" }, dir)

	local config = json.decode(fs.read(path.join(dir, "lde.json")))
	test.falsy(config.dependencies["mypkg"], "dependency should be removed from lde.json")
end)

test.it("lde remove removes the dep entry from lde.lock if present", function()
	local dir = makeProject("remove-lockfile-test", { mypkg = { path = "../mypkg" } })
	fs.write(path.join(dir, "lde.lock"), json.encode({
		version = "1",
		dependencies = {
			mypkg = { path = "../mypkg" },
			other = { path = "../other" }
		}
	}))
	fs.mkdir(path.join(dir, "target"))
	fs.write(path.join(dir, "target", ".installed"), "stale")

	ldecli({ "remove", "mypkg" }, dir)

	local lockRaw = fs.read(path.join(dir, "lde.lock"))
	test.truthy(lockRaw, "lde.lock should still exist")
	local lock = json.decode(lockRaw)
	test.falsy(lock.dependencies["mypkg"], "removed dep should be gone from lde.lock")
	test.truthy(lock.dependencies["other"], "unrelated lockfile entries should be preserved")
	test.falsy(fs.exists(path.join(dir, "target", ".installed")), ".installed should be deleted")
end)
