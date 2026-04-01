local json = {}

local encodeValue

-- ── shared weak stores ────────────────────────────────────────────────────────

-- keyStore[t]  = ordered list of keys
local keyStore  = setmetatable({}, { __mode = "k" })

-- metaStore[t] = {
--   __before  = trivia before the opening brace/bracket,
--   __after   = trivia after the closing brace/bracket,
--   __trailingComma = bool,
--   [key] = {
--     keyStyle   = "ident"|"single"|"double"  (objects only)
--     before     = trivia before the key/value
--     between    = trivia between key and ':'  (objects only)
--     afterColon = trivia after ':'            (objects only)
--     afterValue = trivia after value (before comma or closing)
--     valueStyle = "single"|"double"           (string values only)
--   }
-- }
local metaStore = setmetatable({}, { __mode = "k" })

-- ── encode ────────────────────────────────────────────────────────────────────

local function encodeString(s, style)
	local q = (style == "single") and "'" or '"'
	local replacements = {
		['"']  = '\\"',  ["'"] = "\\'",
		['\\'] = '\\\\',
		['\b'] = '\\b',  ['\f'] = '\\f',
		['\n'] = '\\n',  ['\r'] = '\\r',
		['\t'] = '\\t',
	}
	-- only escape the quote char that matches our chosen delimiter
	local pat = (style == "single") and "[%z\1-\31'\\]" or '[%z\1-\31"\\]'
	return q .. string.gsub(s, pat, function(c)
		return replacements[c] or string.format("\\u%04x", string.byte(c))
	end) .. q
end

local function encodeKey(k, style)
	if style == "ident" then return k end
	return encodeString(k, style or "double")
end

---@param t table
---@param key string
---@param value any
function json.addField(t, key, value)
	t[key] = value
	local keys = keyStore[t]
	if not keys then keys = {}; keyStore[t] = keys end
	keys[#keys + 1] = key
end

---@param t table
---@param key string
function json.removeField(t, key)
	t[key] = nil
	local keys = keyStore[t]
	if not keys then return end
	for i, k in ipairs(keys) do
		if k == key then table.remove(keys, i); return end
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
	local meta = metaStore[t]
	local items = {}
	local nextIndent = string.rep(indent, level + 1)
	for i = 1, #t do
		local km = meta and meta[i]
		local before     = (km and km.before)     or "\n" .. nextIndent
		local afterValue = (km and km.afterValue)  or ""
		items[i] = before .. encodeValue(t[i], indent, level + 1, km and km.valueStyle) .. afterValue
	end
	local trailingComma = meta and meta.__trailingComma and "," or ""
	local closing = (meta and meta.__closingTrivia) or ("\n" .. string.rep(indent, level))
	return "[" .. table.concat(items, ",") .. trailingComma .. closing .. "]"
end

local function encodeObject(t, indent, level)
	local keys = keyStore[t]
	if not keys then
		keys = {}
		for k in pairs(t) do keys[#keys + 1] = k end
		table.sort(keys)
	end
	if #keys == 0 then return "{}" end
	local meta = metaStore[t]
	local parts = {}
	for i, k in ipairs(keys) do
		local km = meta and meta[k]
		local keyStyle   = km and km.keyStyle
		local before     = (km and km.before)     or (i == 1 and " " or " ")
		local between    = (km and km.between)    or ""
		local afterColon = (km and km.afterColon) or " "
		local afterValue = (km and km.afterValue) or ""
		parts[i] = before
			.. encodeKey(tostring(k), keyStyle)
			.. between .. ":" .. afterColon
			.. encodeValue(t[k], indent, level + 1, km and km.valueStyle)
			.. afterValue
	end
	local trailingComma = meta and meta.__trailingComma and "," or ""
	-- if we have preserved meta, use it; otherwise fall back to pretty/inline
	if meta then
		local closing = meta.__closingTrivia or " "
		return "{" .. table.concat(parts, ",") .. trailingComma .. closing .. "}"
	end
	-- no meta: pretty-print
	local inline = "{ " .. table.concat(parts, ", ") .. " }"
	if #inline <= 50 then return inline end
	local nextIndent = string.rep(indent, level + 1)
	local items = {}
	for i, p in ipairs(parts) do items[i] = nextIndent .. p end
	return "{\n" .. table.concat(items, ",\n") .. "\n" .. string.rep(indent, level) .. "}"
end

function encodeValue(v, indent, level, valueStyle)
	local t = type(v)
	if v == nil or v == json.null then
		return "null"
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "number" then
		if v ~= v then return "NaN" end
		if v == math.huge  then return "Infinity"  end
		if v == -math.huge then return "-Infinity" end
		if v == math.floor(v) then return string.format("%d", v) end
		return tostring(v)
	elseif t == "string" then
		return encodeString(v, valueStyle)
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

-- ── decoder ───────────────────────────────────────────────────────────────────

-- Returns (triviaString, newPos).  Trivia = whitespace + comments.
local function collectTrivia(s, pos)
	local start = pos
	while pos <= #s do
		local next = string.match(s, "^%s*()", pos)
		if next ~= pos then pos = next end
		if string.sub(s, pos, pos + 1) == "//" then
			pos = (string.find(s, "\n", pos, true) or #s) + 1
		elseif string.sub(s, pos, pos + 1) == "/*" then
			local e = string.find(s, "*/", pos + 2, true)
			if not e then error("unterminated block comment") end
			pos = e + 2
		else
			break
		end
	end
	return string.sub(s, start, pos - 1), pos
end

local decodeValue

local escapeMap = {
	['"'] = '"', ["'"] = "'", ['\\'] = '\\', ['/'] = '/',
	['b'] = '\b', ['f'] = '\f', ['n'] = '\n', ['r'] = '\r', ['t'] = '\t',
}

-- Returns value, newPos, style ("single"|"double")
local function decodeString(s, pos)
	local quoteChar = string.sub(s, pos, pos)
	local quote = string.byte(s, pos)
	local style = (quoteChar == "'") and "single" or "double"
	local buf = {}
	local i = pos + 1
	while i <= #s do
		local c = string.byte(s, i)
		if c == quote then
			return table.concat(buf), i + 1, style
		elseif c == 92 then
			local esc = string.sub(s, i + 1, i + 1)
			if esc == 'u' then
				local hex = string.sub(s, i + 2, i + 5)
				buf[#buf + 1] = string.char(tonumber(hex, 16))
				i = i + 6
			elseif esc == '\n' or esc == '\r' then
				i = i + 2
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

local function decodeIdentifier(s, pos)
	local id = string.match(s, "^[%a_$][%w_$]*", pos)
	if not id then error("invalid identifier at pos " .. pos) end
	return id, pos + #id
end

local function decodeNumber(s, pos)
	local hex = string.match(s, "^-?0[xX]%x+", pos)
	if hex then return tonumber(hex), pos + #hex end
	if string.sub(s, pos, pos + 7)  == "Infinity"  then return math.huge,   pos + 8 end
	if string.sub(s, pos, pos + 8)  == "+Infinity" then return math.huge,   pos + 9 end
	if string.sub(s, pos, pos + 8)  == "-Infinity" then return -math.huge,  pos + 9 end
	if string.sub(s, pos, pos + 2)  == "NaN"       then return 0/0,         pos + 3 end
	local numStr = string.match(s, "^[+-]?%d+%.?%d*[eE]?[+-]?%d*", pos)
	return tonumber(numStr), pos + #numStr
end

local function decodeArray(s, pos)
	local arr  = {}
	local meta = { __trailingComma = false }
	metaStore[arr] = meta

	local trivia, npos = collectTrivia(s, pos + 1)
	pos = npos
	if string.byte(s, pos) == 93 then
		meta.__closingTrivia = trivia
		return arr, pos + 1
	end

	local i = 0
	while true do
		i = i + 1
		local km = { before = trivia }
		local val, vstyle
		val, pos, vstyle = decodeValue(s, pos)
		km.valueStyle = vstyle
		arr[i] = val

		trivia, pos = collectTrivia(s, pos)
		km.afterValue = trivia
		meta[i] = km

		local c = string.byte(s, pos)
		if c == 93 then
			meta.__closingTrivia = ""
			return arr, pos + 1
		end
		if c ~= 44 then error("expected ',' or ']'") end
		pos = pos + 1
		trivia, pos = collectTrivia(s, pos)
		if string.byte(s, pos) == 93 then
			meta.__trailingComma = true
			meta.__closingTrivia = trivia
			return arr, pos + 1
		end
	end
end

local function decodeObject(s, pos)
	local obj  = {}
	local keys = {}
	local meta = { __trailingComma = false }
	keyStore[obj]  = keys
	metaStore[obj] = meta

	local trivia, npos = collectTrivia(s, pos + 1)
	pos = npos
	if string.byte(s, pos) == 125 then
		meta.__closingTrivia = trivia
		return obj, pos + 1
	end

	while true do
		local km = { before = trivia }
		local c  = string.byte(s, pos)
		local key, keyStyle
		if c == 34 or c == 39 then
			local style
			key, pos, style = decodeString(s, pos)
			keyStyle = style
		else
			key, pos = decodeIdentifier(s, pos)
			keyStyle = "ident"
		end
		km.keyStyle = keyStyle

		trivia, pos = collectTrivia(s, pos)
		km.between = trivia
		if string.byte(s, pos) ~= 58 then error("expected ':'") end
		pos = pos + 1
		trivia, pos = collectTrivia(s, pos)
		km.afterColon = trivia

		local val, vstyle
		val, pos, vstyle = decodeValue(s, pos)
		km.valueStyle = vstyle
		obj[key] = val
		keys[#keys + 1] = key

		trivia, pos = collectTrivia(s, pos)
		km.afterValue = trivia
		meta[key] = km

		c = string.byte(s, pos)
		if c == 125 then
			meta.__closingTrivia = ""
			return obj, pos + 1
		end
		if c ~= 44 then error("expected ',' or '}'") end
		pos = pos + 1
		trivia, pos = collectTrivia(s, pos)
		if string.byte(s, pos) == 125 then
			meta.__trailingComma = true
			meta.__closingTrivia = trivia
			return obj, pos + 1
		end
	end
end

-- Returns value, newPos, valueStyle (only non-nil for strings)
function decodeValue(s, pos)
	local trivia
	trivia, pos = collectTrivia(s, pos)
	local c = string.byte(s, pos)
	if c == 34 or c == 39 then
		local v, npos, style = decodeString(s, pos)
		return v, npos, style
	elseif c == 123 then
		local v, npos = decodeObject(s, pos)
		return v, npos
	elseif c == 91 then
		local v, npos = decodeArray(s, pos)
		return v, npos
	elseif c == 116 then return true,      pos + 4
	elseif c == 102 then return false,     pos + 5
	elseif c == 110 then return json.null, pos + 4
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
