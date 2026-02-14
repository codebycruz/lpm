local env = require("env")

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
}

---@class lpm.ExecuteOptions
---@field env table<string, string>?
---@field args string[]?
---@field globals table<string, any>?
---@field packagePath string?
---@field packageCPath string?

---@param scriptPath string
---@param opts lpm.ExecuteOptions?
local function executeFile(scriptPath, opts)
	opts = opts or {}

	local oldPath, oldCPath = package.path, package.cpath
	local callback, err = loadfile(scriptPath, "t")
	if not callback then
		return false, err or "Failed to compile script"
	end

	-- Save old env var values and set new ones
	local oldEnvVars = {}
	if opts.env then
		for k, v in pairs(opts.env) do
			oldEnvVars[k] = env.var(k)
			env.set(k, v)
		end
	end

	-- Isolate the package library from currently running code and target scripts.
	local oldLoaded = package.loaded
	local oldPreload = package.preload

	local newG = {}
	setmetatable(newG, { __index = _G })
	setfenv(callback, newG)

	local freshLoaded = { _G = newG }
	for k, v in pairs(oldLoaded) do
		if builtinModules[k] then
			freshLoaded[k] = v
		end
	end

	local freshPreload = {}
	for k, v in pairs(oldPreload) do
		if builtinModules[k] then
			freshPreload[k] = v
		end
	end

	-- Wrap package.loaders so that any chunk loaded via require()
	-- also gets its environment set to newG, preventing global pollution.
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

	package.loaded = freshLoaded
	package.preload = freshPreload
	package.loaders = freshLoaders

	local ok, err = pcall(function()
		package.path, package.cpath = opts.packagePath, opts.packageCPath
		if opts.args then
			return callback(unpack(opts.args))
		else
			return callback()
		end
	end)

	-- Restore old env var values
	for k, v in pairs(oldEnvVars) do
		env.set(k, v)
	end

	package.loaded = oldLoaded
	package.preload = oldPreload
	package.loaders = oldLoaders
	package.path, package.cpath = oldPath, oldCPath
	return ok, err
end

return {
	executeFile = executeFile,
}
