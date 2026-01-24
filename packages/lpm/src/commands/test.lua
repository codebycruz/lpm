local Package = require("lpm.package")

local fs = require("fs")
local path = require("path")
local ansi = require("ansi")

---@param args clap.Args
local function test(args)
	local pkg = Package.open()

	local testDir = pkg:getTestDir()
	if not fs.exists(testDir) then
		error("No tests directory found in package: " .. testDir)
	end

	---@type { relativePath: string, msg: string }[]
	local failures = {}

	local testFiles = fs.scan(testDir, "**" .. path.separator .. "*.lua")
	for _, relativePath in ipairs(testFiles) do
		local testFile = path.join(testDir, relativePath)

		local ok, msg = pkg:runScript(testFile)
		if not ok then
			ansi.printf("{red}[FAIL] %s", relativePath)
			failures[#failures + 1] = { relativePath = relativePath, msg = msg }
		end
	end

	local didGetPackageError = false
	if #failures > 0 then
		ansi.printf("{red}\nTest Failures:")
		for _, failure in ipairs(failures) do
			if string.find(failure.msg, "no field package.preload", 1, true) then
				didGetPackageError = true
			end

			print("- " .. failure.relativePath .. ": " .. failure.msg)
		end

		ansi.printf("{red}%d out of %d test(s) failed.", #failures, #testFiles)

		if didGetPackageError then
			ansi.printf(
				"{yellow}\nIt looks like some tests are failing due to missing dependencies. Do you need to run lpm install?")
		end
	else
		ansi.printf("{green}All %d tests passed!", #testFiles)
	end
end

return test
