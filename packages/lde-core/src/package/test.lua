local fs = require("fs")
local path = require("path")
local ffi = require("ffi")
local runtime = require("lde-core.runtime")

---@class lde.TestFileResult
---@field file string
---@field results lde.test.Result[]
---@field error string?

---@class lde.TestReporter
---@field onFileStart? fun(file: string)
---@field onFileDone? fun(file: string)
---@field onStart? fun(name: string): any
---@field onPass? fun(name: string, handle: any)
---@field onFail? fun(name: string, err: string, handle: any)
---@field onSkip? fun(name: string)

---@class lde.TestResults
---@field package lde.Package
---@field files lde.TestFileResult[]
---@field total number
---@field failures number
---@field skipped number
---@field error string?

local function getLuaPathsForPackage(package)
	local modulesDir = package:getModulesDir()

	local luaPath =
		path.join(modulesDir, "?.lua") .. ";"
		.. path.join(modulesDir, "?", "init.lua") .. ";"

	local luaCPath =
		ffi.os == "Linux" and path.join(modulesDir, "?.so") .. ";"
		or ffi.os == "Windows" and path.join(modulesDir, "?.dll") .. ";"
		or path.join(modulesDir, "?.dylib") .. ";"

	return luaPath, luaCPath
end

local ldeTest = require("lde-test.test")

--- Runs tests for this package, optionally filtered by glob patterns.
---@param package lde.Package
---@param reporter? lde.TestReporter
---@param filters? string[] glob patterns to filter test files by
---@return lde.TestResults
local function runTests(package, reporter, filters)
	package:installDependencies()
	package:installDevDependencies()
	package:build()

	local testDir = package:getTestDir()
	if not fs.exists(testDir) then
		return {
			package = package,
			files = {},
			total = 0,
			failures = 0,
			error = "No tests directory found in package: " .. testDir
		}
	end

	local luaPath, luaCPath = getLuaPathsForPackage(package)

	-- Expose tests/ via target/tests so test files can require each other
	local targetTestsDir = path.join(package:getModulesDir(), "tests")
	if not fs.exists(targetTestsDir) then
		if package:hasBuildScript() then
			fs.copy(testDir, targetTestsDir)
		else
			fs.mklink(testDir, targetTestsDir)
		end
	end

	---@type lde.TestFileResult[]
	local files = {}
	local totalTests = 0
	local totalFailures = 0
	local totalSkipped = 0

	local testFiles = fs.scan(testDir, "**" .. path.separator .. "*.test.lua")
	if filters and #filters > 0 then
		local filtered = {}
		for _, relPath in ipairs(testFiles) do
			for _, filterGlob in ipairs(filters) do
				local pattern = fs.globToPattern(filterGlob)
				if string.find(relPath, pattern) then
					filtered[#filtered + 1] = relPath
					break
				end
			end
		end
		testFiles = filtered
	end
	for _, relativePath in ipairs(testFiles) do
		local testFile = path.join(testDir, relativePath)

		if reporter and reporter.onFileStart then
			reporter.onFileStart(relativePath)
		end

		local testObj = ldeTest.new()

		local ok, results = runtime.executeFile(testFile, {
			packagePath = luaPath,
			packageCPath = luaCPath,
			preload = {
				["lpm-test"] = function() return testObj end, -- Compat
				["lde-test"] = function() return testObj end,
				["lde-test.run"] = function() return testObj.run end
			},
			postexec = function() return testObj.run(reporter) end
		})

		if not ok then
			files[#files + 1] = {
				file = relativePath,
				results = {},
				error = results
			}
		else
			local failCount = 0
			local skipCount = 0
			for _, r in ipairs(results) do
				if r.skipped then
					skipCount = skipCount + 1
				elseif not r.ok then
					failCount = failCount + 1
				end
			end

			totalTests = totalTests + #results - skipCount
			totalFailures = totalFailures + failCount
			totalSkipped = totalSkipped + skipCount

			files[#files + 1] = {
				file = relativePath,
				results = results
			}

		end

		if reporter and reporter.onFileDone then
			reporter.onFileDone(relativePath)
		end
	end

	return {
		package = package,
		files = files,
		total = totalTests,
		failures = totalFailures,
		skipped = totalSkipped
	}
end

return runTests
