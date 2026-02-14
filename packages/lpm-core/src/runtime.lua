local env = require("env")

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

	package.path, package.cpath = oldPath, oldCPath
	return ok, err
end

return {
	executeFile = executeFile,
}
