local clap = {}

---@class clap.Args
---@field private kvs table<string, any>
---@field private args any[]
local Args = {}
Args.__index = Args

---@generic T
---@param typeName `T`
---@return T?
function Args:pop(typeName)
	local ty = type(self.args[1])
	if ty == type(typeName) then
		return table.remove(self.args, 1)
	end
end

---@generic T
---@param key string
---@param typeName `T`
---@return T?
function Args:key(key, typeName)
	local val = self.kvs[key]
	if val ~= nil then
		if type(val) == type(typeName) then
			return val
		end
	end
end

---@return number
function Args:count()
	return #self.args
end

---@param key string
---@return boolean
function Args:has(key)
	return self.kvs[key] ~= nil
end

---@param rawArgs string[]
---@return clap.Args
function clap.parse(rawArgs)
	---@type table<string, any>
	local kvs = {}

	local ptr, len = 1, #rawArgs

	---@param val string
	local function parseValue(val)
		if val == "true" then
			return true
		elseif val == "false" then
			return false
		elseif tonumber(val) then
			return tonumber(val)
		else
			return val
		end
	end

	---@param arg string
	local function parseArg(arg)
		if string.sub(arg, 1, 2) == "--" then
			local eq = string.find(arg, "=", 1, true)
			if eq then
				local key = string.sub(arg, 3, eq - 1)
				local value = string.sub(arg, eq + 1)

				kvs[key] = parseValue(value)
			else
				local key = string.sub(arg, 3)
				local nextArg = rawArgs[ptr]
				if nextArg ~= nil and string.sub(nextArg, 1, 1) ~= "-" then
					ptr = ptr + 1
					kvs[key] = parseValue(nextArg)
				else
					kvs[key] = true
				end
			end

			return nil
		end

		return parseValue(arg)
	end

	local args = {}
	while ptr <= len do
		local rawArg = rawArgs[ptr]
		ptr = ptr + 1

		local parsed = parseArg(rawArg)
		if parsed ~= nil then
			args[#args + 1] = parsed
		end
	end

	return setmetatable({
		args = args,
		kvs = kvs,
	}, Args)
end

return clap
