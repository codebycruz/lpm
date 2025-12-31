local fs = {}

local path = require("path")

local isWindows = path.separator == "\\"

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

---@param cwd string
---@param glob string
function fs.scan(cwd, glob)
	local results = {}
	local pattern = fs.globToPattern(glob)

	local function scanRecursive(currentPath)
		local items = fs.listdir(currentPath)
		for _, item in ipairs(items) do
			local fullPath = path.resolve(currentPath, item)

			if fs.isdir(fullPath) then
				scanRecursive(fullPath)
			elseif string.find(fullPath, pattern) then
				results[#results + 1] = path.relative(cwd, fullPath)
			end
		end
	end

	if fs.exists(cwd) and fs.isdir(cwd) then
		scanRecursive(cwd)
	end

	return results
end

---@param p string
function fs.read(p)
	local file = io.open(p, "r")
	if not file then
		return nil
	end

	local content = file:read("*all")
	file:close()

	return content
end

---@param p string
---@param content string
function fs.write(p, content)
	local file = io.open(p, "w")
	if not file then
		return false
	end

	file:write(content)
	file:close()

	return true
end

---@param p string
function fs.exists(p)
	local file = io.open(p, "r")
	if file then
		file:close()
		return true
	else
		return false
	end
end

---@param p string
function fs.mkdir(p)
	if isWindows then
		os.execute("mkdir " .. escape(p))
	else
		os.execute("mkdir -p " .. escape(p))
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

---@param src string
---@param dest string
function fs.move(src, dest)
	os.execute("mv " .. escape(src) .. " " .. escape(dest))
end

return fs
