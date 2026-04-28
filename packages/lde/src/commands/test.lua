local fs = require("fs")
local path = require("path")
local ansi = require("ansi")
local env = require("env")

local lde = require("lde-core")

---@param packageDir string
---@param msg string
local function makeRelative(packageDir, msg)
	local prefix = packageDir .. path.separator
	return (string.gsub(msg, prefix, ""))
end

---@param pkgDir string
---@return lde.TestReporter
local function makeReporter(pkgDir)
	local firstFile = true
	return {
		onFileStart = function(file)
			if not firstFile then
				print()
			end
			firstFile = false
			ansi.printf("  {gray}%s", file)
		end,
		onStart = function(name)
			return ansi.progress(name)
		end,
		onPass = function(name, handle)
			handle:done(name)
		end,
		onFail = function(name, err, handle)
			handle:fail(name)
			ansi.printf("     {red}%s", makeRelative(pkgDir, err or "unknown error"))
		end,
		onSkip = function(name)
			ansi.printf("   {yellow}- {gray}%s {yellow}(skipped)", name)
		end,
	}
end

---@param results lde.TestResults
---@param pkgDir string
local function printFileErrors(results, pkgDir)
	for _, file in ipairs(results.files) do
		if file.error then
			ansi.printf("  {red}FAIL {white}%s", file.file)
			ansi.printf("    {red}%s", makeRelative(pkgDir, file.error))
			print()
		end
	end
end

---@param failures number
---@param passed number
---@param total number
---@param skipped number
local function printSummary(failures, passed, total, skipped)
	local skipStr = skipped > 0 and ansi.format(", {yellow}%d skipped", skipped) or ""
	if failures > 0 then
		ansi.printf("{white}Tests:  {red}%d failed{white}, {green}%d passed{white}, {cyan}%d total" .. skipStr, failures,
			passed, total)
	else
		ansi.printf("{white}Tests:  {green}%d passed{white}, {cyan}%d total" .. skipStr, passed, total)
	end
end

---@param args clap.Args
local function test(args)
	-- Collect remaining positional args as test file filter globs
	local filters = {}
	while true do
		local v = args:pop()
		if not v then break end
		filters[#filters + 1] = v
	end

	local package = lde.Package.open()

	print()

	-- Running outside of a package, run tests for all packages inside of cwd
	if not package then
		local cwd = env.cwd()
		local hadFailures = false
		local totalPassed = 0
		local totalFailures = 0
		local totalSkipped = 0

		local packages = {}
		for _, relativePath in ipairs(fs.scan(cwd, "**" .. path.separator .. "lde.json")) do
			local configPath = path.join(cwd, relativePath)
			local pkgDir = path.dirname(configPath)
			if not fs.isdir(path.join(pkgDir, "tests")) then goto continue end
			local pkg = lde.Package.open(pkgDir)
			if pkg then
				packages[#packages + 1] = pkg
			end
			::continue::
		end

		if #packages == 0 then
			ansi.printf("{yellow}No packages with tests found")
			return
		end

		ansi.printf("{white}Running tests from {cyan}%d {white}%s",
			#packages, #packages == 1 and "package" or "packages")
		print()

		for _, pkg in ipairs(packages) do
			ansi.printf("{gray}%s", pkg:getName())
			print()
			local reporter = makeReporter(pkg:getDir())
			local results = pkg:runTests(reporter, filters)
			if results.error then
				ansi.printf("  {red}%s", results.error)
			elseif #results.files == 0 and #filters > 0 then
				ansi.printf("  {gray}No files matched")
			else
				printFileErrors(results, pkg:getDir())
				totalPassed = totalPassed + (results.total - results.failures)
				totalFailures = totalFailures + results.failures
				totalSkipped = totalSkipped + (results.skipped or 0)
				if results.failures > 0 then hadFailures = true end
			end
			print()
		end

		local totalTests = totalPassed + totalFailures
		printSummary(totalFailures, totalPassed, totalTests, totalSkipped)

		if hadFailures then
			os.exit(1)
		end

		return
	end

	local reporter = makeReporter(package:getDir())
	local results = package:runTests(reporter, filters)
	if results.error then
		ansi.printf("{red}%s", results.error)
	else
		printFileErrors(results, package:getDir())
	end
	print()
	printSummary(results.failures, results.total - results.failures, results.total, results.skipped or 0)
	if results.failures > 0 then
		os.exit(1)
	end
end

return test
