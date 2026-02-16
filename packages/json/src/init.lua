local json = {}

local encodeValue

local function encodeString(s)
	local replacements = {
		['"'] = '\\"',
		['\\'] = '\\\\',
		['\b'] = '\\b',
		['\f'] = '\\f',
		['\n'] = '\\n',
		['\r'] = '\\r',
		['\t'] = '\\t',
	}
	return '"' .. string.gsub(s, '[%z\1-\31"\\]', function(c)
		return replacements[c] or string.format("\\u%04x", string.byte(c))
	end) .. '"'
end

local keyStore = setmetatable({}, { __mode = "k" })

---@param t table
---@param key string
---@param value any
function json.addField(t, key, value)
	t[key] = value
	local keys = keyStore[t]
	if not keys then
		keys = {}
		keyStore[t] = keys
	end
	keys[#keys + 1] = key
end

---@param t table
---@param key string
function json.removeField(t, key)
	t[key] = nil
	local keys = keyStore[t]
	if not keys then return end
	for i, k in ipairs(keys) do
		if k == key then
			table.remove(keys, i)
			return
		end
	end
end

local function isArray(t)
	if keyStore[t] then return false end
	local i = 0
	for _ in pairs(t) do
		i = i + 1
		if t[i] == nil then return false end
	end
	return true
end

local function encodeArray(t, indent, level)
	if #t == 0 then return "[]" end
	local items = {}
	local nextIndent = string.rep(indent, level + 1)
	for i = 1, #t do
		items[i] = nextIndent .. encodeValue(t[i], indent, level + 1)
	end
	return "[\n" .. table.concat(items, ",\n") .. "\n" .. string.rep(indent, level) .. "]"
end

local function encodeObject(t, indent, level)
	local keys = keyStore[t]
	if not keys then
		keys = {}
		for k in pairs(t) do
			keys[#keys + 1] = k
		end
		table.sort(keys)
	end
	if #keys == 0 then return "{}" end
	local parts = {}
	for i, k in ipairs(keys) do
		parts[i] = encodeString(tostring(k)) .. ": " .. encodeValue(t[k], indent, level + 1)
	end
	local inline = "{ " .. table.concat(parts, ", ") .. " }"
	if #inline <= 50 then return inline end
	local items = {}
	local nextIndent = string.rep(indent, level + 1)
	for i, part in ipairs(parts) do
		items[i] = nextIndent .. part
	end
	return "{\n" .. table.concat(items, ",\n") .. "\n" .. string.rep(indent, level) .. "}"
end

function encodeValue(v, indent, level)
	local t = type(v)
	if v == nil or v == json.null then
		return "null"
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "number" then
		if v ~= v then return "null" end
		if v == math.huge or v == -math.huge then return "null" end
		if v == math.floor(v) then return string.format("%d", v) end
		return tostring(v)
	elseif t == "string" then
		return encodeString(v)
	elseif t == "table" then
		if isArray(v) then
			return encodeArray(v, indent, level)
		else
			return encodeObject(v, indent, level)
		end
	end
	error("unsupported type: " .. t)
end

---@param value any
---@return string
function json.encode(value)
	return encodeValue(value, "\t", 0) .. "\n"
end

-- Decoder

local function skipWhitespace(s, pos)
	return string.match(s, "^%s*()", pos)
end

local decodeValue

local escapeMap = {
	['"'] = '"',
	['\\'] = '\\',
	['/'] = '/',
	['b'] = '\b',
	['f'] = '\f',
	['n'] = '\n',
	['r'] = '\r',
	['t'] = '\t',
}

local function decodeString(s, pos)
	local buf = {}
	local i = pos + 1
	while i <= #s do
		local c = string.byte(s, i)
		if c == 34 then -- closing "
			return table.concat(buf), i + 1
		elseif c == 92 then -- backslash
			local esc = string.sub(s, i + 1, i + 1)
			if esc == 'u' then
				local hex = string.sub(s, i + 2, i + 5)
				buf[#buf + 1] = string.char(tonumber(hex, 16))
				i = i + 6
			else
				buf[#buf + 1] = escapeMap[esc] or esc
				i = i + 2
			end
		else
			buf[#buf + 1] = string.char(c)
			i = i + 1
		end
	end
	error("unterminated string")
end

local function decodeNumber(s, pos)
	local numStr = string.match(s, "^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
	return tonumber(numStr), pos + #numStr
end

local function decodeArray(s, pos)
	local arr = {}
	pos = skipWhitespace(s, pos + 1)
	if string.byte(s, pos) == 93 then return arr, pos + 1 end
	while true do
		local val
		val, pos = decodeValue(s, pos)
		arr[#arr + 1] = val
		pos = skipWhitespace(s, pos)
		local c = string.byte(s, pos)
		if c == 93 then return arr, pos + 1 end
		if c ~= 44 then error("expected ',' or ']'") end
		pos = skipWhitespace(s, pos + 1)
	end
end

local function decodeObject(s, pos)
	local obj = {}
	local keys = {}
	keyStore[obj] = keys
	pos = skipWhitespace(s, pos + 1)
	if string.byte(s, pos) == 125 then return obj, pos + 1 end
	while true do
		if string.byte(s, pos) ~= 34 then error("expected string key") end
		local key
		key, pos = decodeString(s, pos)
		pos = skipWhitespace(s, pos)
		if string.byte(s, pos) ~= 58 then error("expected ':'") end
		pos = skipWhitespace(s, pos + 1)
		local val
		val, pos = decodeValue(s, pos)
		obj[key] = val
		keys[#keys + 1] = key
		pos = skipWhitespace(s, pos)
		local c = string.byte(s, pos)
		if c == 125 then return obj, pos + 1 end
		if c ~= 44 then error("expected ',' or '}'") end
		pos = skipWhitespace(s, pos + 1)
	end
end

function decodeValue(s, pos)
	pos = skipWhitespace(s, pos)
	local c = string.byte(s, pos)
	if c == 34 then
		return decodeString(s, pos)
	elseif c == 123 then
		return decodeObject(s, pos)
	elseif c == 91 then
		return decodeArray(s, pos)
	elseif c == 116 then
		return true, pos + 4
	elseif c == 102 then
		return false, pos + 5
	elseif c == 110 then
		return json.null, pos + 4
	else
		return decodeNumber(s, pos)
	end
end

json.null = setmetatable({}, { __tostring = function() return "null" end })

---@param s string
---@return any
function json.decode(s)
	local val = decodeValue(s, 1)
	return val
end

return json
