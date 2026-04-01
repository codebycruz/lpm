local json   = {}
local ffi    = require("ffi")
local strbuf = require("string.buffer")

ffi.cdef [[
	void* memchr(const void* s, int c, size_t n);
]]

local C         = ffi.C

-- ── types ─────────────────────────────────────────────────────────────────────

---@alias json.Primitive string | number | boolean | nil
---@alias json.Value     json.Primitive | json.Object | json.Array | table
---@alias json.Object    table<string, json.Value>
---@alias json.Array     json.Value[]
---@alias json.KeyStyle  "ident" | "single" | "double"
---@alias json.StringStyle "single" | "double"

---@class json.KeyMeta
---@field keyStyle   json.KeyStyle
---@field before     string
---@field between    string
---@field afterColon string
---@field afterValue string
---@field valueStyle json.StringStyle | nil

---@class json.TableMeta
---@field __trailingComma boolean
---@field __closingTrivia string | nil
---@field [string]        json.KeyMeta
---@field [integer]       json.KeyMeta

-- ── weak stores ───────────────────────────────────────────────────────────────

---@type table<table, string[]>
local keyStore  = setmetatable({}, { __mode = "k" })

---@type table<table, json.TableMeta>
local metaStore = setmetatable({}, { __mode = "k" })

-- ── encode (flat string.buffer tape) ─────────────────────────────────────────

---@type table<string, string>
local dq_esc    = {
	['"'] = '\\"',
	['\\'] = '\\\\',
	['\b'] = '\\b',
	['\f'] = '\\f',
	['\n'] = '\\n',
	['\r'] = '\\r',
	['\t'] = '\\t'
}

---@type table<string, string>
local sq_esc    = {
	["'"] = "\\'",
	['\\'] = '\\\\',
	['\b'] = '\\b',
	['\f'] = '\\f',
	['\n'] = '\\n',
	['\r'] = '\\r',
	['\t'] = '\\t'
}

---@param tape  string.buffer
---@param s     string
---@param style json.StringStyle | nil
local function putString(tape, s, style)
	if style == "single" then
		tape:put("'")
		tape:put((string.gsub(s, "[%z\1-\31'\\]", function(c)
			return sq_esc[c] or string.format("\\u%04x", string.byte(c))
		end)))
		tape:put("'")
	else
		tape:put('"')
		tape:put((string.gsub(s, '[%z\1-\31"\\]', function(c)
			return dq_esc[c] or string.format("\\u%04x", string.byte(c))
		end)))
		tape:put('"')
	end
end

---@type fun(tape: string.buffer, v: json.Value, indent: string, level: integer, valueStyle: json.StringStyle | nil)
local putValue -- forward decl

---@param t table
---@return boolean
local function isArray(t)
	if keyStore[t] then return false end
	local i = 0
	for _ in pairs(t) do
		i = i + 1
		if t[i] == nil then return false end
	end
	return true
end

---@param tape   string.buffer
---@param t      json.Array
---@param indent string
---@param level  integer
local function putArray(tape, t, indent, level)
	local n = #t
	if n == 0 then
		tape:put("[]"); return
	end
	local meta = metaStore[t]
	local nextIndent = string.rep(indent, level + 1)
	local defaultBefore = "\n" .. nextIndent
	local closing = (meta and meta.__closingTrivia) or ("\n" .. string.rep(indent, level))
	tape:put("[")
	for i = 1, n do
		if i > 1 then tape:put(",") end
		local km = meta and meta[i]
		tape:put((km and km.before) or defaultBefore)
		putValue(tape, t[i], indent, level + 1, km and km.valueStyle)
		local av = km and km.afterValue
		if av and av ~= "" then tape:put(av) end
	end
	if meta and meta.__trailingComma then tape:put(",") end
	tape:put(closing)
	tape:put("]")
end

---@param tape   string.buffer
---@param t      json.Object
---@param indent string
---@param level  integer
local function putObject(tape, t, indent, level)
	local keys = keyStore[t]
	if not keys then
		keys = {}
		for k in pairs(t) do keys[#keys + 1] = k end
		table.sort(keys)
	end
	local n = #keys
	if n == 0 then
		tape:put("{}"); return
	end
	local meta = metaStore[t]

	if not meta then
		local scratch = strbuf.new()
		scratch:put("{ ")
		for i, k in ipairs(keys) do
			if i > 1 then scratch:put(", ") end
			putString(scratch, tostring(k), nil)
			scratch:put(": ")
			putValue(scratch, t[k], indent, level + 1, nil)
		end
		scratch:put(" }")
		local s = scratch:tostring()
		if #s <= 50 then
			tape:put(s); return
		end
		local nextIndent = string.rep(indent, level + 1)
		tape:put("{\n")
		for i, k in ipairs(keys) do
			if i > 1 then tape:put(",\n") end
			tape:put(nextIndent)
			putString(tape, tostring(k), nil)
			tape:put(": ")
			putValue(tape, t[k], indent, level + 1, nil)
		end
		tape:put("\n")
		tape:put(string.rep(indent, level))
		tape:put("}")
		return
	end

	tape:put("{")
	for i, k in ipairs(keys) do
		if i > 1 then tape:put(",") end
		local km = meta[k]
		tape:put((km and km.before) or " ")
		local ks = km and km.keyStyle
		if ks == "ident" then
			tape:put(tostring(k))
		else
			putString(tape, tostring(k), ks)
		end
		tape:put((km and km.between) or "")
		tape:put(":")
		tape:put((km and km.afterColon) or " ")
		putValue(tape, t[k], indent, level + 1, km and km.valueStyle)
		local av = km and km.afterValue
		if av and av ~= "" then tape:put(av) end
	end
	if meta.__trailingComma then tape:put(",") end
	tape:put(meta.__closingTrivia or " ")
	tape:put("}")
end

local floor = math.floor
local huge  = math.huge

---@param tape string.buffer
---@param v json.Value
---@param indent string
---@param level number
---@param valueStyle json.StringStyle
function putValue(tape, v, indent, level, valueStyle)
	local t = type(v)
	if t == "nil" or v == json.null then
		tape:put("null")
	elseif t == "boolean" then
		tape:put(v and "true" or "false")
	elseif t == "number" then
		if v ~= v then
			tape:put("NaN")
		elseif v == huge then
			tape:put("Infinity")
		elseif v == -huge then
			tape:put("-Infinity")
		elseif v == floor(v) then
			tape:put(string.format("%d", v))
		else
			tape:put(tostring(v))
		end
	elseif t == "string" then
		putString(tape, v, valueStyle)
	elseif t == "table" then
		if isArray(v) then
			putArray(tape, v, indent, level)
		else
			putObject(tape, v, indent, level)
		end
	else
		error("unsupported type: " .. t)
	end
end

---@param t     table
---@param key   string
---@param value json.Value
function json.addField(t, key, value)
	t[key] = value
	local keys = keyStore[t]
	if not keys then
		keys = {}; keyStore[t] = keys
	end
	keys[#keys + 1] = key
end

---@param t   table
---@param key string
function json.removeField(t, key)
	t[key] = nil
	local keys = keyStore[t]
	if not keys then return end
	for i, k in ipairs(keys) do
		if k == key then
			table.remove(keys, i); return
		end
	end
end

---@param value json.Value
---@return string
function json.encode(value)
	local tape = strbuf.new()
	putValue(tape, value, "\t", 0, nil)
	tape:put("\n")
	return tape:tostring()
end

-- ── decoder ───────────────────────────────────────────────────────────────────

---@type ffi.cdata*  kept alive by src_s
local src_ptr
---@type integer
local src_len
---@type string
local src_s

---@param pos integer  1-based
---@return integer     1-based
local function skipWS(pos)
	local i = pos - 1
	while i < src_len do
		local b = src_ptr[i]
		if b ~= 32 and b ~= 9 and b ~= 10 and b ~= 13 then break end
		i = i + 1
	end
	return i + 1
end

---@param pos         integer  1-based, sitting on '/'
---@param triviaStart integer  1-based start of trivia span
---@return string trivia
---@return integer    1-based position after trivia
local function collectComments(pos, triviaStart)
	while pos <= src_len do
		local b1 = src_ptr[pos]
		if src_ptr[pos - 1] ~= 47 then break end
		if b1 == 47 then -- '//'
			local nl = C.memchr(src_ptr + pos + 1, 10, src_len - pos - 1)
			pos = nl ~= nil and (ffi.cast("const uint8_t*", nl) - src_ptr + 2) or (src_len + 1)
		elseif b1 == 42 then -- '/*'
			local p     = src_ptr + pos + 1
			local rem   = src_len - pos - 1
			local found = false
			while rem > 0 do
				local star = C.memchr(p, 42, rem)
				if star == nil then error("unterminated block comment") end
				local sp  = ffi.cast("const uint8_t*", star)
				local off = sp - src_ptr
				if off + 1 < src_len and src_ptr[off + 1] == 47 then
					pos   = off + 3
					found = true
					break
				end
				p   = sp + 1
				rem = src_len - (off + 1)
			end
			if not found then error("unterminated block comment") end
		else
			break
		end
		pos = skipWS(pos)
	end
	return string.sub(src_s, triviaStart, pos - 1), pos
end

---@param pos integer  1-based
---@return string  trivia (whitespace + comments)
---@return integer 1-based position after trivia
local function collectTrivia(pos)
	local npos = skipWS(pos)
	if npos <= src_len and src_ptr[npos - 1] == 47 then
		return collectComments(npos, pos)
	end
	return string.sub(src_s, pos, npos - 1), npos
end

---@type fun(pos: integer): json.Value, integer, json.StringStyle | nil
local decodeValue -- forward decl

---@type table<integer, string>
local escapeMap = {
	[34] = '"',
	[39] = "'",
	[92] = '\\',
	[47] = '/',
	[98] = '\b',
	[102] = '\f',
	[110] = '\n',
	[114] = '\r',
	[116] = '\t'
}

---@param pos integer  1-based, pointing at opening quote
---@return string       decoded string value
---@return integer      1-based position after closing quote
---@return json.StringStyle  quote style used
local function decodeString(pos)
	local quote = src_ptr[pos - 1]
	local style = (quote == 39) and "single" or "double" --[[@as json.StringStyle]]
	local buf   = {}
	local i     = pos + 1
	while i <= src_len do
		local rem    = src_len - i + 1
		local base   = src_ptr + i - 1
		local pbs    = C.memchr(base, 92, rem)
		local pq     = C.memchr(base, quote, rem)
		local bs_off = pbs ~= nil and (ffi.cast("const uint8_t*", pbs) - src_ptr) or src_len
		local q_off  = pq ~= nil and (ffi.cast("const uint8_t*", pq) - src_ptr) or src_len
		if q_off <= bs_off then
			if q_off >= src_len then error("unterminated string") end
			if q_off > i - 1 then buf[#buf + 1] = string.sub(src_s, i, q_off) end
			return table.concat(buf), q_off + 2, style
		end
		if bs_off > i - 1 then buf[#buf + 1] = string.sub(src_s, i, bs_off) end
		local esc = src_ptr[bs_off + 1]
		if esc == 117 then
			buf[#buf + 1] = string.char(tonumber(string.sub(src_s, bs_off + 2, bs_off + 5), 16))
			i = bs_off + 7
		elseif esc == 10 or esc == 13 then
			i = bs_off + 3
		else
			buf[#buf + 1] = escapeMap[esc] or string.char(esc)
			i = bs_off + 3
		end
	end
	error("unterminated string")
end

---@param pos integer  1-based
---@return string  identifier
---@return integer 1-based position after identifier
local function decodeIdentifier(pos)
	local id = string.match(src_s, "^[%a_$][%w_$]*", pos)
	if not id then error("invalid identifier at pos " .. pos) end
	return id, pos + #id
end

---@param pos integer  1-based
---@return number  parsed number
---@return integer 1-based position after number
local function decodeNumber(pos)
	local hex = string.match(src_s, "^-?0[xX]%x+", pos)
	if hex then return tonumber(hex), pos + #hex end
	local sub = string.sub(src_s, pos, pos + 8)
	if sub:sub(1, 8) == "Infinity" then return huge, pos + 8 end
	if sub:sub(1, 9) == "+Infinity" then return huge, pos + 9 end
	if sub:sub(1, 9) == "-Infinity" then return -huge, pos + 9 end
	if sub:sub(1, 3) == "NaN" then return 0 / 0, pos + 3 end
	local numStr = string.match(src_s, "^[+-]?%d+%.?%d*[eE]?[+-]?%d*", pos)
	return tonumber(numStr), pos + #numStr
end

---@param pos integer  1-based, pointing at '['
---@return json.Array
---@return integer     1-based position after ']'
local function decodeArray(pos)
	local arr          = {} --[[@as json.Array]]
	local meta         = { __trailingComma = false } --[[@as json.TableMeta]]
	metaStore[arr]     = meta

	local trivia, npos = collectTrivia(pos + 1)
	pos                = npos
	if src_ptr[pos - 1] == 93 then
		meta.__closingTrivia = trivia
		return arr, pos + 1
	end

	local i = 0
	while true do
		i = i + 1
		local km = { before = trivia } --[[@as json.KeyMeta]]
		local val, vstyle
		val, pos, vstyle = decodeValue(pos)
		km.valueStyle = vstyle
		arr[i] = val

		trivia, pos = collectTrivia(pos)
		km.afterValue = trivia
		meta[i] = km

		local c = src_ptr[pos - 1]
		if c == 93 then
			meta.__closingTrivia = ""
			return arr, pos + 1
		end
		if c ~= 44 then error("expected ',' or ']'") end
		pos = pos + 1
		trivia, pos = collectTrivia(pos)
		if src_ptr[pos - 1] == 93 then
			meta.__trailingComma = true
			meta.__closingTrivia = trivia
			return arr, pos + 1
		end
	end
end

---@param pos integer  1-based, pointing at '{'
---@return json.Object
---@return integer     1-based position after '}'
local function decodeObject(pos)
	local obj          = {} --[[@as json.Object]]
	local keys         = {} --[[@as string[] ]]
	local meta         = { __trailingComma = false } --[[@as json.TableMeta]]
	keyStore[obj]      = keys
	metaStore[obj]     = meta

	local trivia, npos = collectTrivia(pos + 1)
	pos                = npos
	if src_ptr[pos - 1] == 125 then
		meta.__closingTrivia = trivia
		return obj, pos + 1
	end

	while true do
		local km = { before = trivia } --[[@as json.KeyMeta]]
		local c  = src_ptr[pos - 1]
		local key, keyStyle
		if c == 34 or c == 39 then
			local style
			key, pos, style = decodeString(pos)
			keyStyle = style
		else
			key, pos = decodeIdentifier(pos)
			keyStyle = "ident"
		end
		km.keyStyle = keyStyle --[[@as json.KeyStyle]]

		trivia, pos = collectTrivia(pos)
		km.between = trivia
		if src_ptr[pos - 1] ~= 58 then error("expected ':'") end
		pos = pos + 1
		trivia, pos = collectTrivia(pos)
		km.afterColon = trivia

		local val, vstyle
		val, pos, vstyle = decodeValue(pos)
		km.valueStyle = vstyle
		obj[key] = val
		keys[#keys + 1] = key

		trivia, pos = collectTrivia(pos)
		km.afterValue = trivia
		meta[key] = km

		c = src_ptr[pos - 1]
		if c == 125 then
			meta.__closingTrivia = ""
			return obj, pos + 1
		end
		if c ~= 44 then error("expected ',' or '}'") end
		pos = pos + 1
		trivia, pos = collectTrivia(pos)
		if src_ptr[pos - 1] == 125 then
			meta.__trailingComma = true
			meta.__closingTrivia = trivia
			return obj, pos + 1
		end
	end
end

---@param pos integer  1-based
---@return json.Value
---@return integer       1-based position after value
---@return json.StringStyle | nil
decodeValue = function(pos)
	local trivia
	trivia, pos = collectTrivia(pos)
	local c = src_ptr[pos - 1]
	if c == 34 or c == 39 then
		return decodeString(pos)
	elseif c == 123 then
		return decodeObject(pos)
	elseif c == 91 then
		return decodeArray(pos)
	elseif c == 116 then
		return true, pos + 4, nil
	elseif c == 102 then
		return false, pos + 5, nil
	elseif c == 110 then
		return json.null, pos + 4, nil
	else
		return decodeNumber(pos)
	end
end

json.null = setmetatable({}, { __tostring = function() return "null" end })

---@param s string
---@return json.Value
function json.decode(s)
	src_s   = s
	src_len = #s
	src_ptr = ffi.cast("const uint8_t*", s)
	return decodeValue(1)
end

return json
