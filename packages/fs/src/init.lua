local fs = {}

fs.separator = package.config:sub(1, 1)

local isWindows = fs.separator == "\\"

---@param arg string
local function escape(arg)
	if isWindows then
		return '"' .. string.gsub(arg, '"', '\\"') .. '"'
	else
		return "'" .. string.gsub(arg, "'", "'\\''") .. "'"
	end
end

function fs.globToPattern(glob)
	local pattern = glob
		:gsub("([%^%$%(%)%%%.%[%]%+%-])", "%%%1")
		:gsub("%*%*", "\001")
		:gsub("%*", "[^/]*")
		:gsub("%?", "[^/]")
		:gsub("\001", ".*")

	return "^" .. pattern .. "$"
end

---@param path string
---@param glob string
function fs.scan(path, glob)
	local results = {}
	local pattern = fs.globToPattern(glob)

	local function scanRecursive(currentPath)
		local items = fs.listdir(currentPath)
		for _, item in ipairs(items) do
			local fullPath = fs.resolve(currentPath, item)

			if fs.isdir(fullPath) then
				scanRecursive(fullPath)
			elseif string.find(fullPath, pattern) then
				results[#results + 1] = fullPath
			end
		end
	end

	if fs.exists(path) and fs.isdir(path) then
		scanRecursive(path)
	end

	return results
end

---@param path string
function fs.read(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end

	local content = file:read("*all")
	file:close()

	return content
end

---@param path string
---@param content string
function fs.write(path, content)
	local file = io.open(path, "w")
	if not file then
		return false
	end

	file:write(content)
	file:close()

	return true
end

---@param path string
function fs.exists(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	else
		return false
	end
end

---@param path string
function fs.mkdir(path)
	if isWindows then
		os.execute("mkdir " .. escape(path))
	else
		os.execute("mkdir -p " .. escape(path))
	end
end

---@param src string
---@param dest string
function fs.mklink(src, dest)
	if isWindows then
		os.execute("mklink /D " .. escape(dest) .. " " .. escape(src))
	else
		os.execute("ln -s " .. escape(src) .. " " .. escape(dest))
	end
end

function fs.cwd()
	local handle = io.popen("pwd")
	local cwd = handle:read("*all"):gsub("\n$", "")
	handle:close()
	return cwd
end

---@param path string
function fs.basename(path)
	return string.match(path, "([^/]+)$") or path
end

---@param path string
function fs.listdir(path)
	local files = {}
	local handle = io.popen("ls -1 " .. escape(path) .. " 2>/dev/null")
	if handle then
		for line in handle:lines() do
			table.insert(files, line)
		end
		handle:close()
	end
	return files
end

---@param path string
function fs.isdir(path)
	if isWindows then
		local handle = io.popen('if exist "' .. path .. '\\*" (echo yes) else (echo no)')
		local result = handle:read("*a")
		handle:close()
		return result:match("yes") ~= nil
	else
		local handle = io.popen("test -d " .. escape(path) .. " && echo yes || echo no")
		local result = handle:read("*a")
		handle:close()
		return result:match("yes") ~= nil
	end
end

---@param src string
---@param dest string
function fs.copy(src, dest)
	os.execute("cp -r " .. escape(src) .. " " .. escape(dest))
end

---@param base string
---@param relative string
function fs.resolve(base, relative)
	if string.sub(relative, 1, 1) == "/" then
		return relative
	end

	local path
	if string.sub(base, -1) == "/" then
		path = base .. relative
	else
		path = base .. "/" .. relative
	end

	-- Normalize the path by resolving .. and . components
	local parts = {}
	for part in string.gmatch(path, "[^/]+") do
		if part == ".." then
			if #parts > 0 then
				table.remove(parts)
			end
		elseif part ~= "." then
			table.insert(parts, part)
		end
	end

	local result = "/" .. table.concat(parts, "/")
	-- Handle relative paths that don't start with /
	if string.sub(path, 1, 1) ~= "/" then
		result = table.concat(parts, "/")
		if #parts == 0 then
			result = "."
		end
	end

	return result
end

return fs
