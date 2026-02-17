---@alias lpm.test.Result
--- | { name: string, ok: true }
--- | { name: string, ok: false, error: string }

---@class lpm.test
---@field it fun(name: string, fn: fun())
---@field run fun(): lpm.test.Result[]
---@field equal fun(a: any, b: any)
---@field notEqual fun(a: any, b: any)
local M = {}

---@generic T
---@param a T
---@param b T
local function equal(a, b)
	if a ~= b then
		error("Expected " .. tostring(a) .. " to equal " .. tostring(b), 2)
	end
end

---@generic T
---@param a T
---@param b T
local function notEqual(a, b)
	if a == b then
		error("Expected " .. tostring(a) .. " not to equal " .. tostring(b), 2)
	end
end

--- Creates a fresh, independent test instance.
---@return lpm.test
function M.new()
	local callbacks = {}

	local instance = {}

	function instance.it(name, fn)
		table.insert(callbacks, { name = name, callback = fn })
	end

	function instance.run()
		---@type lpm.test.Result[]
		local results = {}

		for _, callback in ipairs(callbacks) do
			local ok, err = pcall(callback.callback)
			table.insert(results, { name = callback.name, ok = ok, error = err })
		end

		return results
	end

	instance.equal = equal
	instance.notEqual = notEqual

	return instance
end

return M
