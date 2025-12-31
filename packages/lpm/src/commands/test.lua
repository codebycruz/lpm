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

	local testFiles = fs.scan(testDir, "**/*.lua")
	for _, relativePath in ipairs(testFiles) do
		local testFile = path.join(testDir, relativePath)

		local ok, msg = pkg:runScript(testFile)
		if not ok then
			print(ansi.colorize(ansi.red, "[FAIL]") .. " " .. relativePath)
			failures[#failures + 1] = { relativePath = relativePath, msg = msg }
		end
	end

	if #failures > 0 then
		print(ansi.colorize(ansi.red, "\nTest Failures:"))
		for _, failure in ipairs(failures) do
			print("- " .. failure.relativePath .. ": " .. failure.msg)
		end

		print(ansi.colorize(ansi.red, #failures .. " out of " .. #testFiles .. " test(s) failed."))
	else
		print(ansi.colorize(ansi.green, "All " .. #testFiles .. " tests passed!"))
	end
end

return test
