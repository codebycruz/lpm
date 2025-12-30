local path = {}

local separator = string.sub(package.config, 1, 1)

function path.join(...)
	return table.concat({ ... }, separator)
end

return path
