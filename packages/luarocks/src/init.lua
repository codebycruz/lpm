local ROCKSPEC_BASE = "https://luarocks.org"

local luarocks = {}

---@class luarocks.Manifest.Entry
---@field arch string

---@class luarocks.Manifest
---@field _raw string
local Manifest = {}
Manifest.__index = Manifest

---@param raw string
---@return luarocks.Manifest
function Manifest.new(raw)
	return setmetatable({ _raw = raw }, Manifest)
end

---@param name string
---@return table<string, luarocks.Manifest.Entry[]>?
function Manifest:package(name)
	local escaped = name:gsub("([%-%.%+%*%?%[%]%^%$%(%)%%])", "%%%1")
	-- Try quoted key: ["name"] = {
	local start = self._raw:find('%["' .. escaped .. '"%]%s*=%s*{')
	-- Fall back to unquoted ident key with frontier pattern: name = {
	if not start then
		start = self._raw:find('%f[%w_]' .. escaped .. '%f[^%w_]%s*=%s*{')
	end
	if not start then return nil end

	local i = self._raw:find("{", start)
	local depth, blockStart = 0, i
	while i <= #self._raw do
		local c = self._raw:sub(i, i)
		if c == "{" then depth = depth + 1
		elseif c == "}" then
			depth = depth - 1
			if depth == 0 then break end
		end
		i = i + 1
	end
	local block = self._raw:sub(blockStart, i)

	local versions = {}
	for verKey, verBody in block:gmatch('%["([^"]+)"%]%s*=%s*(%b{})') do
		local entries = {}
		for arch in verBody:gmatch('arch%s*=%s*"([^"]+)"') do
			entries[#entries + 1] = { arch = arch }
		end
		versions[verKey] = entries
	end

	return versions
end

---@param manifest luarocks.Manifest
---@param name string
---@return table<string, string>? # version -> url
---@return string? err
function luarocks.getRockspecUrls(manifest, name)
	local versions = manifest:package(name)
	if not versions then
		return nil, "Package not found in luarocks registry: " .. name
	end

	local urls = {}
	for ver, entries in pairs(versions) do
		for _, entry in ipairs(entries) do
			if entry.arch == "rockspec" then
				urls[ver] = string.format("%s/%s-%s.rockspec", ROCKSPEC_BASE, name, ver)
				break
			end
		end
	end

	if not next(urls) then
		return nil, "No rockspec entries found for: " .. name
	end

	return urls
end

---@param v string
---@return number[]
local function parseVer(v)
	local parts = {}
	for n in (v:match("^([^%-]+)") or v):gmatch("%d+") do
		parts[#parts + 1] = tonumber(n)
	end
	return parts
end

---@param a number[]
---@param b number[]
---@return number
local function cmpVer(a, b)
	for i = 1, math.max(#a, #b) do
		local d = (a[i] or 0) - (b[i] or 0)
		if d ~= 0 then return d end
	end
	return 0
end

---@param ver string
---@param op string
---@param constraint string
---@return boolean
local function satisfies(ver, op, constraint)
	local c = cmpVer(parseVer(ver), parseVer(constraint))
	if op == ">=" then return c >= 0
	elseif op == ">" then return c > 0
	elseif op == "<=" then return c <= 0
	elseif op == "<" then return c < 0
	elseif op == "==" or op == "=" then return c == 0
	elseif op == "~=" then return c ~= 0
	end
	return false
end

---@param manifest luarocks.Manifest
---@param name string
---@param constraint string?
---@return string? rockspecUrl
---@return string? err
function luarocks.getRockspecUrl(manifest, name, constraint)
	local urls, err = luarocks.getRockspecUrls(manifest, name)
	if not urls then return nil, err end

	local sorted = {}
	for v in pairs(urls) do sorted[#sorted + 1] = v end
	table.sort(sorted, function(a, b) return cmpVer(parseVer(a), parseVer(b)) > 0 end)

	if not constraint or constraint == "" then
		return urls[sorted[1]]
	end

	local constraints = {}
	for op, ver in constraint:gmatch("([><=~!]+)%s*([%d%.%-]+)") do
		constraints[#constraints + 1] = { op = op, ver = ver }
	end

	if #constraints == 0 then
		local url = urls[constraint]
		return url or nil, url and nil or "Version '" .. constraint .. "' not found for: " .. name
	end

	for _, v in ipairs(sorted) do
		local ok = true
		for _, c in ipairs(constraints) do
			if not satisfies(v, c.op, c.ver) then ok = false; break end
		end
		if ok then return urls[v] end
	end

	return nil, "No version of '" .. name .. "' satisfies: " .. constraint
end

luarocks.Manifest = Manifest

return luarocks
