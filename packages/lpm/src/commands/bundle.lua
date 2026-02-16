local ansi = require("ansi")
local fs = require("fs")
local path = require("path")

local Package = require("lpm-core.package")

local stringEscapes = {
	["\\"] = "\\\\",
	['"'] = '\\"',
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
	["\a"] = "\\a",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\v"] = "\\v",
}

---@param s string
---@return string
local function escapeString(s)
	return (string.gsub(s, '[\\\"\n\r\t\a\b\f\v]', stringEscapes))
end

---@param projectName string
---@param dir string
---@param files table<string, string>
local function bundleDir(projectName, dir, files)
	for _, relativePath in ipairs(fs.scan(dir, "**" .. path.separator .. "*.lua")) do
		local absPath = path.join(dir, relativePath)
		local content = fs.read(absPath)
		if not content then
			error("Could not read file: " .. absPath)
		end

		local moduleName = relativePath:gsub(path.separator, "."):gsub("%.lua$", ""):gsub("%.?init$", "")
		if moduleName ~= "" then
			moduleName = projectName .. "." .. moduleName
		else
			moduleName = projectName
		end

		files[moduleName] = content
	end
end

---@param args clap.Args
local function bundle(args)
	local outFile = args:option("outfile")

	local pkg, err = Package.open()
	if not pkg then
		ansi.printf("{red}%s", err)
		return
	end

	if not outFile then
		outFile = path.join(pkg:getDir(), pkg:getName() .. ".lua")
	end

	pkg:build()
	pkg:installDependencies()

	local files = {}
	local modulesDir = pkg:getModulesDir()

	bundleDir(pkg:getName(), path.join(modulesDir, pkg:getName()), files)

	for depName in pairs(pkg:getDependencies()) do
		bundleDir(depName, path.join(modulesDir, depName), files)
	end

	local parts = {}
	for moduleName, content in pairs(files) do
		parts[#parts + 1] = string.format(
			'package.preload["%s"] = load("%s", "@%s")',
			moduleName, escapeString(content), moduleName
		)
	end

	parts[#parts + 1] = string.format('return package.preload["%s"](...)', pkg:getName())

	fs.write(outFile, table.concat(parts, "\n") .. "\n")
	ansi.printf("{green}Bundled to %s", outFile)
end

return bundle
