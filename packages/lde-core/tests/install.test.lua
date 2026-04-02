local test = require("lde-test")

local fs = require("fs")
local env = require("env")
local path = require("path")
local process = require("process")

local tmpBase = path.join(env.tmpdir(), "lde-install-tests")
fs.rmdir(tmpBase)
fs.mkdir(tmpBase)

-- Derive repo root from this file's location (tests/ -> packages/lde/ -> packages/ -> repo root)
local thisFile = debug.getinfo(1, "S").source:sub(2)
local repoRoot = path.join(path.dirname(thisFile), "..", "..", "..")

local installScript = process.platform == "win32"
	and path.join(repoRoot, "install.ps1")
	or path.join(repoRoot, "install.sh")

test.skipIf(process.platform ~= "win32" or jit.arch ~= "x64")(
	"install.ps1 installs lde binary to %USERPROFILE%\\.lde\\lde.exe", function()
		local fakeProfile = path.join(tmpBase, "userprofile")
		fs.mkdir(fakeProfile)

		local ok, err = process.exec("powershell", {
			"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", installScript
		}, {
			env = { USERPROFILE = fakeProfile }
		})
		if not ok then print(err) end

		test.truthy(ok)
		test.truthy(fs.exists(path.join(fakeProfile, ".lde", "lde.exe")))
	end)

test.skipIf(process.platform ~= "win32" or jit.arch ~= "x64")("installed lde.exe responds to --version", function()
	local fakeProfile = path.join(tmpBase, "userprofile2")
	fs.mkdir(fakeProfile)

	local ok, err = process.exec("powershell", {
		"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", installScript
	}, {
		env = { USERPROFILE = fakeProfile }
	})
	if not ok then print(err) end
	test.truthy(ok)

	local ldeBin = path.join(fakeProfile, ".lde", "lde.exe")
	local ok2, _ = process.exec(ldeBin, { "--version" })
	test.truthy(ok2)
end)

if process.platform == "win32" and jit.arch ~= "x64" then
	test.skip("install script tests (unsupported arch: " .. jit.arch .. ")")
end

test.skipIf(process.platform ~= "linux")("install.sh installs lde binary to $HOME/.lde/lde", function()
	local fakeHome = path.join(tmpBase, "home")
	fs.mkdir(fakeHome)

	local ok, _ = process.exec("sh", { installScript }, {
		env = { HOME = fakeHome }
	})

	test.truthy(ok)
	test.truthy(fs.exists(path.join(fakeHome, ".lde", "lde")))
end)

test.skipIf(process.platform ~= "linux")("installed lde binary responds to --version", function()
	local fakeHome = path.join(tmpBase, "home2")
	fs.mkdir(fakeHome)

	local ok, _ = process.exec("sh", { installScript }, {
		env = { HOME = fakeHome }
	})
	test.truthy(ok)

	local ldeBin = path.join(fakeHome, ".lde", "lde")
	local ok2, _ = process.exec(ldeBin, { "--version" })
	test.truthy(ok2)
end)
