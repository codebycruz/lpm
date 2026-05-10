local sea = require("sea")
local fs = require("fs")
local path = require("path")

local lde = require("lde-core")

local bundlePackage = require("lde-core.package.bundle")
local exportMod = require("lde-core.package.export")

local nativeExt = jit.os == "Windows" and "dll"
	or jit.os == "OSX" and "dylib"
	or "so"

---Collect shared libraries embedded in the modules directory.
---@param modulesDir string
---@return { name: string, content: string }[]
local function collectSharedLibs(modulesDir)
	local sharedLibs = {}

	for entry in fs.readdir(modulesDir) do
		local p = path.join(modulesDir, entry.name)
		if not fs.isdir(p) then
			local ext = entry.name:match("%." .. nativeExt .. "$")
			if ext then
				local content = fs.read(p)
				if not content then error("Could not read file: " .. p) end
				local moduleName = entry.name:gsub("%." .. nativeExt .. "$", "")
				table.insert(sharedLibs, { name = moduleName, content = content })
			end
			goto continue
		end

		for _, relativePath in ipairs(fs.scan(p, "**" .. path.separator .. "*." .. nativeExt)) do
			local absPath = path.join(p, relativePath)
			local content = fs.read(absPath)
			if not content then error("Could not read file: " .. absPath) end

			local moduleName = string.gsub(relativePath, path.separator, "."):gsub("%." .. nativeExt .. "$", "")
			moduleName = moduleName ~= "" and (entry.name .. "." .. moduleName) or entry.name
			table.insert(sharedLibs, { name = moduleName, content = content })
		end

		::continue::
	end

	return sharedLibs
end

---@param package lde.Package
---@return string
local function compilePackage(package)
	package:build()
	package:installDependencies()

	local source = bundlePackage(package)
	local sharedLibs = collectSharedLibs(package:getModulesDir())

	return sea.compile(package:getName(), source, sharedLibs, lde.global.getGCCBin())
end

---Compile the package as a shared library (.so / .dll / .dylib).
---Scans the entrypoint for ---@export annotations and generates exported C symbols.
---@param package lde.Package
---@return string outPath
local function compilePackageShared(package)
	package:build()
	package:installDependencies()

	local modulesDir = package:getModulesDir()
	local config = package:readConfig()
	local pkgName = package:getName()

	-- Determine entrypoint file and its module name in the bundle
	local entrypointRel = config.bin or "init.lua"
	local entrypointPath = path.join(package:getTargetDir(), entrypointRel)

	if not fs.exists(entrypointPath) then
		error("Entry point not found: " .. entrypointPath .. " (package may be a library with no runnable entry point)")
	end

	local originalSource = fs.read(entrypointPath)
	if not originalSource then
		error("Could not read entry point: " .. entrypointPath)
	end

	-- Parse ---@export annotations and inject export registration code in-memory
	local modifiedSource, exports = exportMod.processSourceWithExports(originalSource)

	-- Determine the module name for the entrypoint in the bundle.
	-- For default entrypoint (init.lua), the module name is the package name.
	-- For custom bin (e.g. src/main.lua -> target/<name>/main.lua), module name is <name>.main
	local entrypointModuleName
	if entrypointRel == "init.lua" then
		entrypointModuleName = pkgName
	else
		entrypointModuleName = pkgName .. "." .. entrypointRel:gsub("%.lua$", "")
	end

	-- Bundle the package, injecting the modified entrypoint via sourceOverrides
	local source = bundlePackage(package, {
		sourceOverrides = { [entrypointModuleName] = modifiedSource }
	})
	local sharedLibs = collectSharedLibs(modulesDir)

	-- Build shared library data (from sea)
	local libData = sea.buildSharedLibData(sharedLibs)

	-- Combine Lua source with shims
	if libData.ffiShim ~= "" then
		source = libData.ffiShim .. "\n" .. source
	end
	source = libData.tmpnameShim .. "\n" .. source

	-- Debug: dump bundled Lua source and generated C to stderr
	io.stderr:write("-- bundled Lua source:\n" .. source .. "\n-- end Lua source\n")
	io.stderr:write("-- exports: " .. #exports .. "\n")

	-- Generate the C code for the shared library
	local cCode = exportMod.generateSharedLibraryC(
		exports,
		source,
		libData.libDeclsStr,
		libData.libStartupStr,
		libData.libPreloadsStr,
		libData.loadlibHelper,
		"", -- ffiShim already applied to source
		"" -- tmpnameShim already applied to source
	)

	-- Debug: dump generated C source
	io.stderr:write("-- generated C source:\n" .. cCode .. "\n-- end C source\n")

	-- Compile the shared library
	local outPath = sea.compileShared(cCode, lde.global.getGCCBin())

	return outPath
end

return {
	compile = compilePackage,
	compileShared = compilePackageShared
}
