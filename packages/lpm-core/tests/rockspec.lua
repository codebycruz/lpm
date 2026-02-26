local test = require("lpm-test")
local Package = require("lpm-core.package")
local fs = require("fs")
local path = require("path")
local runtime = require("lpm-core.runtime")
local ffi = require("ffi")

-- Build a temporary directory for a fake rocks package, run cleanup on exit.
local function makeTempDir()
	local tmpBase = (jit.os == "Windows" and os.getenv("TEMP") or "/tmp") .. path.separator
	local dir = tmpBase .. "lpm-test-rockspec-" .. tostring(math.random(1e9))
	fs.mkdir(dir)
	return dir
end

local function rmdir(dir)
	fs.rmdir(dir)
end

-- ---------------------------------------------------------------------------
-- The key scenario:
--   The rockspec maps the module name "mylib.stuff" to the source file
--   "lib/stuff.lua".  Without the generated init.lua wrapper this require()
--   would fail because the standard searcher looks for "mylib/stuff.lua", not
--   "lib/stuff.lua".
-- ---------------------------------------------------------------------------

test.it("openRocks: module at non-standard path is requireable via rockspec mapping", function()
	local dir = makeTempDir()

	-- src/lib/stuff.lua  (not at mylib/stuff.lua - deliberately non-standard)
	fs.mkdir(path.join(dir, "src"))
	fs.mkdir(path.join(dir, "src", "lib"))
	fs.write(path.join(dir, "src", "lib", "stuff.lua"), [[
		return { value = "hello from mylib.stuff" }
	]])

	-- Write a rockspec whose build.modules entry maps "mylib.stuff" → "lib/stuff.lua"
	fs.write(path.join(dir, "mylib-1.0-1.rockspec"), [[
		package = "mylib"
		version = "1.0-1"
		source  = { url = "https://example.com" }
		build   = {
			type    = "builtin",
			modules = {
				["mylib.stuff"] = "lib/stuff.lua",
			},
		}
	]])

	local pkg, err = Package.openRocks(dir)
	if not pkg then
		rmdir(dir)
		error("openRocks failed: " .. tostring(err))
	end

	test.equal(pkg:getName(), "mylib")

	-- Build the package so the target dir + generated init.lua are created.
	pkg:build()

	-- Write a small runner script that require()s the non-standard module and
	-- asserts the expected value is returned.
	-- Note: require("mylib") must be called first so the generated init.lua
	-- registers its package.preload entries for submodules.
	local runnerPath = path.join(dir, "runner.lua")
	fs.write(runnerPath, [[
		require("mylib")
		local m = require("mylib.stuff")
		assert(m ~= nil, "require('mylib.stuff') returned nil")
		assert(m.value == "hello from mylib.stuff",
			"unexpected value: " .. tostring(m.value))
	]])

	local modulesDir = pkg:getModulesDir()
	local luaPath =
		path.join(modulesDir, "?.lua") .. ";"
		.. path.join(modulesDir, "?", "init.lua") .. ";"

	local luaCPath =
		ffi.os == "Linux" and path.join(modulesDir, "?.so") .. ";"
		or ffi.os == "Windows" and path.join(modulesDir, "?.dll") .. ";"
		or path.join(modulesDir, "?.dylib") .. ";"

	local ok, runErr = runtime.executeFile(runnerPath, {
		packagePath = luaPath,
		packageCPath = luaCPath,
	})

	rmdir(dir)

	if not ok then
		error("runner script failed: " .. tostring(runErr))
	end
end)
