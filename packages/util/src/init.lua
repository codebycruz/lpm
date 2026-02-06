local util = {}

---@param str string
function util.dedent(str)
	local lines = {}
	for line in (str .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end

	local minIndent = math.huge
	for _, line in ipairs(lines) do
		if line:match("%S") then
			local indent = line:match("^%s*")
			minIndent = math.min(minIndent, #indent)
		end
	end

	if minIndent == math.huge or minIndent == 0 then
		return str
	end

	for i, line in ipairs(lines) do
		if line:match("%S") then
			lines[i] = line:sub(minIndent + 1)
		end
	end

	local result = table.concat(lines, "\n")
	return result:match("^(.-)%s*$") or result
end

return util
