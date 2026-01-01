local path = {}

path.separator = string.sub(package.config, 1, 1)

local isWindows = path.separator == "\\"

---@param p string
function path.basename(p)
	return string.match(p, "([^" .. path.separator .. "]+)$") or ""
end

---@param p string
function path.dirname(p)
	return p:match("^(.*)" .. path.separator) or "."
end

local windowsDriveLetter = "^%a:\\"

---@param p string
function path.isAbsolute(p)
	if string.sub(p, 1, 1) == path.separator then
		return true
	end

	if isWindows then
		return string.match(p, windowsDriveLetter) ~= nil
	end
end

---@param p string
function path.parts(p)
	return string.gmatch(p, "[^/\\]+")
end

---@param p string
function path.root(p)
	local root = string.sub(p, 1, 1)
	if root == path.separator then
		return root
	end

	if isWindows then
		root = string.match(p, windowsDriveLetter)
		if root then
			return root
		end
	end
end

function path.normalize(p)
	local root = path.root(p) -- Root if absolute
	local isRelative = root == nil
	local parts = {}

	for part in path.parts(p) do
		if part == ".." then
			if #parts > 0 and parts[#parts] ~= ".." then
				table.remove(parts)
			elseif isRelative then
				parts[#parts + 1] = ".."
			end
		elseif part ~= "." and part ~= "" then
			parts[#parts + 1] = part
		end
	end

	if #parts == 0 then
		return root or "."
	else
		local result = table.concat(parts, path.separator)
		if root and root == path.separator then
			return root .. result
		else
			return result
		end
	end
end

---@param base string
---@param relative string
function path.resolve(base, relative)
	if path.isAbsolute(relative) then
		return path.normalize(relative)
	end

	return path.normalize(base .. path.separator .. relative)
end

---@param ... string
function path.join(...)
	return table.concat({ ... }, path.separator)
end

---@param from string
---@param to string
function path.relative(from, to)
	from = path.normalize(from)
	to = path.normalize(to)

	local fromParts = {}
	for part in path.parts(from) do fromParts[#fromParts + 1] = part end

	local toParts = {}
	for part in path.parts(to) do toParts[#toParts + 1] = part end

	local commonLength = 0
	for i = 1, math.min(#fromParts, #toParts) do
		if fromParts[i] == toParts[i] then
			commonLength = i
		else
			break
		end
	end

	local relativeParts = {}
	for _ = commonLength + 1, #fromParts do relativeParts[#relativeParts + 1] = ".." end
	for i = commonLength + 1, #toParts do relativeParts[#relativeParts + 1] = toParts[i] end

	if #relativeParts == 0 then
		return "."
	end

	return table.concat(relativeParts, path.separator)
end

return path
