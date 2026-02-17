local Package = require("lpm-core.package")

local fs = require("fs")
local path = require("path")
local ansi = require("ansi")
local env = require("env")

---@param packageDir string
---@param msg string
local function makeRelative(packageDir, msg)
	local prefix = packageDir .. path.separator
	return (msg:gsub(prefix, ""))
end

---@param results lpm.TestResults
---@return boolean hadFailures
local function printResults(results)
	if results.error then
		error(results.error)
	end

	local pkgDir = results.package:getDir()

	for _, file in ipairs(results.files) do
		if file.error then
			ansi.printf(" {red}FAIL {white}%s", file.file)
			ansi.printf("   {red}%s", makeRelative(pkgDir, file.error))
		else
			local fileHasFailures = false
			for _, r in ipairs(file.results) do
				if not r.ok then
					fileHasFailures = true
					break
				end
			end

			if fileHasFailures then
				ansi.printf(" {red}FAIL {white}%s", file.file)
			else
				ansi.printf(" {green}PASS {white}%s", file.file)
			end

			for _, r in ipairs(file.results) do
				if r.ok then
					ansi.printf("   {green}\xE2\x9C\x93 {gray}%s", r.name)
				else
					ansi.printf("   {red}\xE2\x9C\x97 %s", r.name)
					ansi.printf("     {red}%s", makeRelative(pkgDir, r.error or "unknown error"))
				end
			end
		end

		print()
	end

	local passed = results.total - results.failures

	if results.failures > 0 then
		ansi.printf("{white}Tests:  {red}%d failed{white}, {green}%d passed{white}, %d total", results.failures, passed,
			results.total)
	else
		ansi.printf("{white}Tests:  {green}%d passed{white}, %d total", passed, results.total)
	end

	return results.failures > 0
end

---@param args clap.Args
local function test(args)
	local package = Package.open()

	print()

	-- Running outside of a package, run tests for all packages inside of cwd
	if not package then
		local cwd = env.cwd()
		local hadFailures = false

		-- Recursively search for packages
		for _, relativePath in ipairs(fs.scan(cwd, "**" .. path.separator .. "lpm.json")) do
			local configPath = path.join(cwd, relativePath)

			local pkg = Package.open(path.dirname(configPath))
			if pkg then
				local results = pkg:runTests()
				if printResults(results) then
					hadFailures = true
				end
			end
		end

		if hadFailures then
			os.exit(1)
		end

		return
	end

	local results = package:runTests()
	if printResults(results) then
		os.exit(1)
	end
end

return test
