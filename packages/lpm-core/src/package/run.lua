local fs = require("fs")
local path = require("path")
local ffi = require("ffi")
local process = require("process")
local runtime = require("lpm-core.runtime")

---@param package lpm.Package
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

---@param package lpm.Package
---@param scriptPath string
---@param args string[]?
---@param vars table<string, string>? # Env vars
local function runScriptWithLPM(package, scriptPath, args, vars)
	local luaPath, luaCPath = getLuaPathsForPackage(package)

	return runtime.executeFile(scriptPath, {
		args = args,
		env = vars,
		cwd = package:getDir(),
		packagePath = luaPath,
		packageCPath = luaCPath,
	})
end

---@param package lpm.Package
---@param scriptPath string
---@param args string[]?
---@param vars table<string, string>? # Env vars
---@param engine string
local function runScriptWithLuaCLI(package, scriptPath, args, vars, engine)
	local luaPath, luaCPath = getLuaPathsForPackage(package)

	local env = { LUA_PATH = luaPath, LUA_CPATH = luaCPath }
	if vars then
		for k, v in pairs(vars) do
			env[k] = v
		end
	end

	return process.exec(engine, { scriptPath }, { cwd = package:getDir(), env = env, stdout = "inherit", stderr = "inherit" })
end

--- Runs a script within the package context
--- This will use the package's engine and set up the LUA_PATH accordingly
---@param package lpm.Package
---@param scriptPath string? # Defaults to bin field or target/<name>/init.lua
---@param args string[]? # Positional arguments
---@param vars table<string, string>? # Additional environment variables
---@return boolean? # Success
---@return string # Output
local function runScript(package, scriptPath, args, vars)
	-- Ensure package is built so modules folder exists (and so it can require itself)
	package:build()

	local config = package:readConfig()

	if not scriptPath then
		if config.bin then
			scriptPath = path.join(package:getTargetDir(), config.bin)
		else
			scriptPath = path.join(package:getTargetDir(), "init.lua")
		end
	end

	local engine = config.engine or "lpm"
	if engine == "lpm" then
		return runScriptWithLPM(package, scriptPath, args, vars)
	else
		return runScriptWithLuaCLI(package, scriptPath, args, vars, engine)
	end
end

return runScript
