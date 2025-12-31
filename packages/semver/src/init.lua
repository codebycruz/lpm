local semver = {}

---@param v1 string
---@param v2 string
---@return number
function semver.compare(v1, v2)
	local function parse(v)
		local major, minor, patch = v:match("(%d+)%.(%d+)%.(%d+)")
		return tonumber(major), tonumber(minor), tonumber(patch)
	end

	local maj1, min1, patch1 = parse(v1)
	local maj2, min2, patch2 = parse(v2)

	if maj1 ~= maj2 then return maj1 - maj2 end
	if min1 ~= min2 then return min1 - min2 end
	return patch1 - patch2
end

return semver
