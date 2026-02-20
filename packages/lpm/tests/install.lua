local test = require("lpm-test")

local fs = require("fs")
local env = require("env")
local path = require("path")
local process = require("process")

local tmpBase = path.join(env.tmpdir(), "lpm-install-tests")
fs.rmdir(tmpBase)
fs.mkdir(tmpBase)

-- From packages/lpm (cwd when tests run), go up two levels to the repo root
local repoRoot = path.join(env.cwd(), "..", "..")

local isWindows = process.platform == "win32"

if isWindows then
	local installScript = path.join(repoRoot, "install.ps1")

	test.it("install.ps1 installs lpm binary to %USERPROFILE%\\.lpm\\lpm.exe", function()
		local fakeProfile = path.join(tmpBase, "userprofile")
		fs.mkdir(fakeProfile)

		local ok, _ = process.exec("powershell", {
			"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", installScript,
		}, {
			env = { USERPROFILE = fakeProfile },
		})

		test.equal(ok, true)
		test.equal(fs.exists(path.join(fakeProfile, ".lpm", "lpm.exe")), true)
	end)

	test.it("installed lpm.exe responds to --version", function()
		local fakeProfile = path.join(tmpBase, "userprofile2")
		fs.mkdir(fakeProfile)

		local ok, _ = process.exec("powershell", {
			"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", installScript,
		}, {
			env = { USERPROFILE = fakeProfile },
		})
		test.equal(ok, true)

		local lpmBin = path.join(fakeProfile, ".lpm", "lpm.exe")
		local ok2, _ = process.exec(lpmBin, { "--version" })
		test.equal(ok2, true)
	end)
else
	local installScript = path.join(repoRoot, "install.sh")

	test.it("install.sh installs lpm binary to $HOME/.lpm/lpm", function()
		local fakeHome = path.join(tmpBase, "home")
		fs.mkdir(fakeHome)

		local ok, _ = process.exec("bash", { installScript }, {
			env = { HOME = fakeHome },
		})

		test.equal(ok, true)
		test.equal(fs.exists(path.join(fakeHome, ".lpm", "lpm")), true)
	end)

	test.it("installed lpm binary responds to --version", function()
		local fakeHome = path.join(tmpBase, "home2")
		fs.mkdir(fakeHome)

		local ok, _ = process.exec("bash", { installScript }, {
			env = { HOME = fakeHome },
		})
		test.equal(ok, true)

		local lpmBin = path.join(fakeHome, ".lpm", "lpm")
		local ok2, _ = process.exec(lpmBin, { "--version" })
		test.equal(ok2, true)
	end)
end
