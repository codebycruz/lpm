local semver = {}

---@class semver.Version
---@field major number
---@field minor number
---@field patch number

---@param v string
---@return semver.Version
function semver.parse(v)
	local major, minor, patch = v:match("(%d+)%.(%d+)%.(%d+)")
	return {
		major = tonumber(major) or 0,
		minor = tonumber(minor) or 0,
		patch = tonumber(patch) or 0
	}
end

---@param v1 string
---@param v2 string
---@return number # negative if v1 < v2, 0 if equal, positive if v1 > v2
function semver.compare(v1, v2)
	local a = semver.parse(v1)
	local b = semver.parse(v2)

	if a.major ~= b.major then return a.major - b.major end
	if a.minor ~= b.minor then return a.minor - b.minor end
	return a.patch - b.patch
end

--- Returns true if candidate is a compatible update for current:
--- same major version, and candidate > current (minor or patch bump).
---@param current string
---@param candidate string
---@return boolean
function semver.isCompatibleUpdate(current, candidate)
	local c = semver.parse(current)
	local n = semver.parse(candidate)
	return n.major == c.major and semver.compare(candidate, current) > 0
end

return semver
