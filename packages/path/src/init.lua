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

---@param p string
function path.isAbsolute(p)
	if isWindows then
		return string.match(p, "^%a:\\") ~= nil or string.sub(p, 1, 1) == path.separator
	else
		return string.sub(p, 1, 1) == path.separator
	end
end

---@param p string
function path.parts(p)
	return string.gmatch(p, "[^" .. path.separator .. "]+")
end

---@param p string
function path.normalize(p)
	local isAbsolute = path.isAbsolute(p)

	local parts = {}
	for part in path.parts(p) do
		if part == ".." then
			if #parts > 0 then
				table.remove(parts)
			end
		elseif part ~= "." and part ~= "" then
			parts[#parts + 1] = part
		end
	end

	if #parts == 0 then
		return isAbsolute and path.separator or "."
	elseif isAbsolute then
		return path.separator .. table.concat(parts, path.separator)
	else
		return table.concat(parts, path.separator)
	end
end

---@param base string
---@param relative string
function path.resolve(base, relative)
	if path.isAbsolute(relative) then
		return path.normalize(relative)
	else
		return path.normalize(base .. path.separator .. relative)
	end
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
