local test = require("lpm-test")

local fs = require("fs")
local env = require("env")
local path = require("path")
local json = require("json")

local Package = require("lpm-core.package")
local runtime = require("lpm-core.runtime")

local tmpBase = path.join(env.tmpdir(), "lpm-main-tests")

-- Clean up from any previous test run
fs.rmdir(tmpBase)

--
-- runtime.executeFile
--

test.it("runtime.executeFile runs a Lua script", function()
	fs.mkdir(tmpBase)
	local scriptPath = path.join(tmpBase, "hello.lua")
	fs.write(scriptPath, 'return 42')

	local ok, err = runtime.executeFile(scriptPath)
	test.equal(ok, true)
end)

test.it("runtime.executeFile returns false for scripts that error", function()
	fs.mkdir(tmpBase)
	local scriptPath = path.join(tmpBase, "fail.lua")
	fs.write(scriptPath, 'error("intentional error")')

	local ok, err = runtime.executeFile(scriptPath)
	test.equal(ok, false)
	test.notEqual(err, nil)
end)

test.it("runtime.executeFile supports preloaded modules", function()
	fs.mkdir(tmpBase)
	local scriptPath = path.join(tmpBase, "preload.lua")
	fs.write(scriptPath, [[
		local m = require("fake-mod")
		if m.value ~= 123 then
			error("preload failed")
		end
	]])

	local ok, err = runtime.executeFile(scriptPath, {
		preload = {
			["fake-mod"] = function() return { value = 123 } end,
		},
	})
	test.equal(ok, true)
end)

test.it("runtime.executeFile isolates globals between runs", function()
	fs.mkdir(tmpBase)
	local script1 = path.join(tmpBase, "global1.lua")
	fs.write(script1, 'MY_GLOBAL_VAR = "leaked"')

	local script2 = path.join(tmpBase, "global2.lua")
	fs.write(script2, [[
		if MY_GLOBAL_VAR ~= nil then
			error("global leaked from another script")
		end
	]])

	runtime.executeFile(script1)
	local ok, err = runtime.executeFile(script2)
	test.equal(ok, true)
end)

--
-- End-to-end: init + build + verify structure
--

test.it("end-to-end: init, build, and verify package structure", function()
	fs.mkdir(tmpBase)
	local dir = path.join(tmpBase, "e2e-project")
	fs.mkdir(dir)

	local pkg = Package.init(dir)
	test.notEqual(pkg, nil)
	test.equal(pkg:getName(), "e2e-project")

	fs.mkdir(pkg:getModulesDir())
	pkg:build()

	test.equal(fs.exists(pkg:getTargetDir()), true)
end)

--
-- pkg:runScript bin field resolution
--

test.it("runScript: uses bin as default entry point when set", function()
	fs.mkdir(tmpBase)
	local dir = path.join(tmpBase, "bin-run-test")
	fs.mkdir(dir)

	fs.write(path.join(dir, "lpm.json"), json.encode({
		name = "bin-run-test",
		version = "0.1.0",
		bin = "cli.lua",
		dependencies = {},
	}))

	local srcDir = path.join(dir, "src")
	fs.mkdir(srcDir)
	fs.write(path.join(srcDir, "init.lua"), 'error("should not run init.lua")')
	fs.write(path.join(srcDir, "cli.lua"), 'return true')

	local pkg = Package.open(dir)
	local ok, err = pkg:runScript(nil, {})
	test.equal(ok, true)
end)

test.it("runScript: falls back to init.lua when bin is not set", function()
	fs.mkdir(tmpBase)
	local dir = path.join(tmpBase, "bin-run-fallback")
	fs.mkdir(dir)

	fs.write(path.join(dir, "lpm.json"), json.encode({
		name = "bin-run-fallback",
		version = "0.1.0",
		dependencies = {},
	}))

	local srcDir = path.join(dir, "src")
	fs.mkdir(srcDir)
	fs.write(path.join(srcDir, "init.lua"), 'return true')

	local pkg = Package.open(dir)
	local ok, err = pkg:runScript(nil, {})
	test.equal(ok, true)
end)

--
-- End-to-end: init + build + verify structure
--

test.it("end-to-end: package with dependency can install and build", function()
	fs.mkdir(tmpBase)

	local libDir = path.join(tmpBase, "e2e-lib")
	fs.mkdir(libDir)
	fs.mkdir(path.join(libDir, "src"))
	fs.write(path.join(libDir, "src", "init.lua"), 'return { greet = function() return "hi" end }')
	fs.write(path.join(libDir, "lpm.json"), json.encode({
		name = "e2e-lib",
		version = "0.1.0",
		dependencies = {},
	}))

	local appDir = path.join(tmpBase, "e2e-app")
	fs.mkdir(appDir)
	fs.mkdir(path.join(appDir, "src"))
	fs.write(path.join(appDir, "src", "init.lua"), 'local lib = require("e2e-lib"); return lib.greet()')
	fs.write(path.join(appDir, "lpm.json"), json.encode({
		name = "e2e-app",
		version = "0.1.0",
		dependencies = {
			["e2e-lib"] = { path = "../e2e-lib" },
		},
	}))

	local app = Package.open(appDir)
	test.notEqual(app, nil)

	app:installDependencies()
	app:build()

	test.equal(fs.exists(path.join(appDir, "target", "e2e-lib", "init.lua")), true)
	test.equal(fs.exists(path.join(appDir, "target", "e2e-app")), true)
end)
