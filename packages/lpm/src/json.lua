local NULL = {}

local find, match, sub, byte, tonumber, error = string.find, string.match, string.sub, string.byte, tonumber, error
local function decode(json --[[@param json string]]) ---@return any
	local ptr = 1

	local function skip(pattern --[[@param pattern string]]) ---@return true?
		local finish = match(json, pattern, ptr)
		if finish then
			ptr = finish
			return true
		end
	end

	local function slowstring() -- string parser that supports escapes.
		local start = ptr
		while true do
			local _start, before_quote, after_quote = match(json, "()\\*()\"()", ptr)
			if _start then
				ptr = after_quote
				if (before_quote - _start) % 2 == 0 then
					return sub(json, start, after_quote) -- return (gsub(sub(json, start, finish - 1), "\\([bfnrt\\\"])", ESCAPES))
				end
			else
				error("Missing end quote for string at char " .. ptr)
			end
		end
	end


	local function number()
		local number, finish = match(json, "^(-?%d*.?%d+[eE]?[+-]?%d*)()", ptr - 1)
		if finish then
			ptr = finish
			return tonumber(number)
		end
	end

	local value
	local function whitespace()
		ptr = match(json, "^%s*()", ptr) or ptr -- skip past whitespace, return immediate value
		return value()
	end

	local peek = {
		[ 34 --[["]] ] = function()
			local start = ptr
			local quot = find(json, '"', start, true)
			local prev = quot - 1
			if byte(json, prev) ~= 92 --[[\]] then
				ptr = quot + 1
				return sub(json, start, prev)
			else
				return slowstring()
			end
		end,
		[ 116 --[[t]] ] = function()
			if sub(json, ptr, ptr + 2) == "rue" then
				ptr = ptr + 3
				return true
			end
		end,
		[ 102 --[[f]] ] = function()
			if sub(json, ptr, ptr + 3) == "alse" then
				ptr = ptr + 4
				return false
			end
		end,
		[ 110 --[[n]] ] = function()
			if sub(json, ptr, ptr + 2) == "ull" then
				ptr = ptr + 3
				return NULL
			end
		end,

		[ 48 --[[0]] ] = number,
		[49] = number,
		[50] = number,
		[51] = number,
		[52] = number,
		[53] = number,
		[54] = number,
		[55] = number,
		[56] = number,
		[ 57 --[[9]] ] = number,
		[ 45 --[[-]] ] = number,

		[ 123 --[[{]] ] = function()
			local fields = {}
			if skip("^%s*}()") then return fields end

			repeat
				ptr = match(json, "()%S", ptr) or ptr -- skip whitespace inline

				if byte(json, ptr) ~= 34 --[["]] then
					error("Expected field for object at char " .. ptr)
				end

				local start = ptr + 1
				local quot = find(json, '"', start, true)

				local prev = quot - 1
				local key

				if byte(json, prev) ~= 92 --[[\]] then
					ptr = quot + 1
					key = sub(json, start, prev)
				else
					key = slowstring()
				end

				if not skip("^%s*:()") then
					error("Expected : to follow key for object at char " .. ptr)
				end

				local val = value()
				if val ~= nil then
					fields[key] = val
				else
					error("Expected value for field " .. key .. " at char " .. ptr)
				end

				ptr = match(json, "^%s*,()", ptr) or ptr
			until skip("^%s*}()")

			return fields
		end,

		[ 91 --[=[]]=] ] = function()
			local values, nvalues = {}, 0
			if skip("^%s*%]()") then return values end

			repeat
				local value = value()
				if value ~= nil then
					nvalues = nvalues + 1
					values[nvalues] = value
				else
					error("Expected value for field #" .. nvalues .. " at char " .. ptr)
				end

				ptr = match(json, "^%s*,()", ptr) or ptr
			until skip("^%s*%]()")

			return values
		end,

		[ 9 --[[\t]] ] = whitespace,
		[ 10 --[[\n]] ] = whitespace,
		[ 13 --[[\r]] ] = whitespace,
		[ 32 --[[ ]] ] = whitespace,
	}

	function value()
		local p = peek[byte(json, ptr)]
		if p then
			ptr = ptr + 1
			return p()
		else
			error("Failed parsing at character " .. ptr)
		end
	end

	return value()
end

local concat, tostring, format, pairs, type = table.concat, tostring, string.format, pairs, type

local function isarray(t, len)
	for k in pairs(t) do
		if len == 0 or type(k) ~= "number" then
			return false
		else
			len = len - 1
		end
	end

	return true
end

local _encode
local function value(v, buffer, nbuffer)
	local t = type(v)
	if t == "table" then
		return _encode(v, buffer, nbuffer)
	elseif t == "string" then
		buffer[nbuffer + 1] = format("%q", v)
	else
		buffer[nbuffer + 1] = tostring(v)
	end
	return nbuffer + 1
end

function _encode(tbl --[[@param tbl table]], buffer --[[@param buffer table]], nbuffer --[[@param nbuffer integer]])
	local len = #tbl
	if isarray(tbl, len) then
		nbuffer = nbuffer + 1
		buffer[nbuffer] = "["

		for i = 1, len do
			nbuffer = value(tbl[i], buffer, nbuffer) + 1
			buffer[nbuffer] = ","
		end

		if len == 0 then -- no trailing comma to replace. need to increment ptr
			nbuffer = nbuffer + 1
		end

		buffer[nbuffer] = "]"
	else
		nbuffer = nbuffer + 1
		buffer[nbuffer] = "{"

		local prev = nbuffer
		for k, v in pairs(tbl) do
			nbuffer = nbuffer + 1
			buffer[nbuffer] = "\"" .. tostring(k) .. "\":"
			nbuffer = value(v, buffer, nbuffer) + 1
			buffer[nbuffer] = ","
		end

		if nbuffer == prev then -- no trailing comma to replace. need to increment ptr
			nbuffer = nbuffer + 1
		end

		buffer[nbuffer] = "}"
	end

	return nbuffer
end

local function encode(tbl --[[@param tbl table]]) ---@return string
	local buffer = {}
	return concat(buffer, "", 1, _encode(tbl, buffer, 0))
end

return {
	NULL = NULL,
	encode = encode,
	decode = decode
}
