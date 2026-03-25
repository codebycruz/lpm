local http = require("http")

local MANIFEST_URL = "https://luarocks.org/manifest"
local ROCKSPEC_BASE = "https://luarocks.org"

local luarocks = {}

---@class luarocks.ManifestEntry
---@field arch string

---@class luarocks.Manifest
---@field repository table<string, table<string, luarocks.ManifestEntry[]>>
---@field modules table
---@field commands table

local baseEnv = { pairs = pairs, ipairs = ipairs, next = next }

---@type luarocks.Manifest?
local cachedManifest

---@return luarocks.Manifest?, string?
local function getManifest()
	if cachedManifest then return cachedManifest end

	local content, err = http.get(MANIFEST_URL)
	if not content then
		return nil, "Failed to fetch manifest: " .. (err or "")
	end

	local chunk, lerr = loadstring(content, "t")
	if not chunk then return nil, lerr end

	local oh, om, oc = debug.gethook()
	debug.sethook(function() error("Manifest took too long") end, "", 1e7)
	local env = setmetatable({}, { __index = baseEnv })
	setfenv(chunk, env)
	jit.off(chunk)
	local ok, out = pcall(chunk)
	debug.sethook(oh, om, oc)

	if not ok then return nil, tostring(out) end

	cachedManifest = env --[[@as luarocks.Manifest]]
	return cachedManifest
end

---@param name string
---@return table<string, string>? # version -> url
---@return string? err
function luarocks.getRockspecUrls(name)
	local manifest, err = getManifest()
	if not manifest then
		return nil, err
	end

	local versions = manifest.repository[name]
	if not versions then
		return nil, "Package not found in registry: " .. name
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

	return urls
end

---@param name string
---@param version string? # e.g. "1.0.0-1"; if nil, picks latest
---@return string? rockspecUrl
---@return string? err
function luarocks.getRockspecUrl(name, version)
	local urls, err = luarocks.getRockspecUrls(name)
	if not urls then return nil, err end

	if version then
		return urls[version] or nil, urls[version] and nil or "Version '" .. version .. "' not found for package: " .. name
	end

	local sorted = {}
	for v in pairs(urls) do sorted[#sorted + 1] = v end
	table.sort(sorted, function(a, b) return a > b end)

	local url = urls[sorted[1]]
	return url or nil, url and nil or "No rockspec entry found for: " .. name
end

---@param name string
---@param version string?
---@return string? rockspecContent
---@return string? err
function luarocks.getRockspec(name, version)
	local url, err = luarocks.getRockspecUrl(name, version)
	if not url then return nil, err end

	local content, fetchErr = http.get(url)
	if not content then
		return nil, "Failed to fetch rockspec: " .. (fetchErr or "")
	end

	return content
end

return luarocks
