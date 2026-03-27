local env = require("env")
local ffi = require("ffi")

local originalCdef = ffi.cdef

local builtinModules = {
	package = true,
	string = true,
	table = true,
	math = true,
	io = true,
	os = true,
	debug = true,
	coroutine = true,
	bit = true,
	jit = true,
	ffi = true,
	["jit.opt"] = true,
	["jit.util"] = true,
	["string.buffer"] = true
}

---@class lpm.ExecuteOptions
---@field env table<string, string>?
---@field args string[]?
---@field globals table<string, any>?
---@field packagePath string?
---@field packageCPath string?
---@field preload table<string, function>?
---@field cwd string?

--- Clears non-builtin entries from a table, returning the saved contents.
---@param t table
---@return table saved
local function clearNonBuiltins(t)
	local saved = {}
	for k, v in pairs(t) do
		saved[k] = v
		if not builtinModules[k] then
			t[k] = nil
		end
	end
	return saved
end

--- Restores a table's contents from a saved snapshot.
---@param t table
---@param saved table
local function restore(t, saved)
	for k in pairs(t) do
		t[k] = nil
	end
	for k, v in pairs(saved) do
		t[k] = v
	end
end

---@param chunk function
---@param opts lpm.ExecuteOptions?
local function executeChunk(chunk, opts)
	opts = opts or {}

	local oldCwd = opts.cwd and env.cwd()
	if opts.cwd then env.chdir(opts.cwd) end

	local oldPath, oldCPath = package.path, package.cpath

	local oldEnvVars = {}
	if opts.env then
		for k, v in pairs(opts.env) do
			oldEnvVars[k] = env.var(k)
			env.set(k, v)
		end
	end

	local savedLoaded = clearNonBuiltins(package.loaded)
	local savedPreload = clearNonBuiltins(package.preload)

	if opts.preload then
		for k, v in pairs(opts.preload) do
			package.preload[k] = v
		end
	end

	local newG = setmetatable({}, { __index = _G })
	setfenv(chunk, newG)
	package.loaded._G = newG

	local oldLoaders = package.loaders
	local freshLoaders = {}
	for i, loader in ipairs(oldLoaders) do
		freshLoaders[i] = function(modname)
			local result = loader(modname)
			if type(result) == "function" then
				pcall(setfenv, result, newG)
			end
			return result
		end
	end
	package.loaders = freshLoaders

	ffi.cdef = function(def)
		local ok, err = pcall(originalCdef, def)
		if not ok and not string.find(err, "attempt to redefine", 1, true) then
			error(err, 2)
		end
	end

	local ok, err = pcall(function()
		package.path = opts.packagePath or oldPath
		package.cpath = opts.packageCPath or oldCPath
		if opts.args then
			arg = opts.args
			return chunk(unpack(opts.args))
		else
			return chunk()
		end
	end)

	for k, v in pairs(oldEnvVars) do env.set(k, v) end
	if oldCwd then env.chdir(oldCwd) end

	ffi.cdef = originalCdef
	restore(package.loaded, savedLoaded)
	restore(package.preload, savedPreload)
	package.loaders = oldLoaders
	package.path, package.cpath = oldPath, oldCPath

	return ok, err
end

---@param scriptPath string
---@param opts lpm.ExecuteOptions?
local function executeFile(scriptPath, opts)
	local chunk, err = loadfile(scriptPath, "t")
	if not chunk then
		return false, err or "Failed to compile script"
	end
	return executeChunk(chunk, opts)
end

---@param code string
---@param opts lpm.ExecuteOptions?
local function executeString(code, opts)
	local chunk, err = loadstring("return " .. code, "-e")
	if not chunk then
		chunk, err = loadstring(code, "-e")
	end
	if not chunk then
		return false, err
	end
	return executeChunk(chunk, opts)
end

return {
	executeFile = executeFile,
	executeString = executeString,
}
