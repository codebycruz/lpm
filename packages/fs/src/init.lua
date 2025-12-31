local fs = {}

local path = require("path")
local process = require("process")

local isWindows = path.separator == "\\"

function fs.globToPattern(glob)
	local pattern = glob
		:gsub("([%^%$%(%)%%%.%[%]%+%-])", "%%%1")
		:gsub("%*%*", "\001")
		:gsub("%*", "[^/]*")
		:gsub("%?", "[^/]")
		:gsub("\001", ".*")

	return "^" .. pattern .. "$"
end

function fs.tmpfile()
	return os.tmpname()
end

math.randomseed(os.time())

---@param prefix string?
function fs.tmpdir(prefix)
	prefix = prefix or "lua"

	local tmp = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
	local rnd = math.random(100000, 999999)

	local dir = path.join(tmp, prefix .. "_" .. tostring(os.time()) .. "_" .. rnd)
	fs.mkdir(dir)

	return dir
end

---@param cwd string
---@param glob string
function fs.scan(cwd, glob)
	local results = {}
	local pattern = fs.globToPattern(glob)

	local function scanRecursive(currentPath, visited)
		if visited[currentPath] then return end
		visited[currentPath] = true

		local items = fs.listdir(currentPath)
		for _, item in ipairs(items) do
			local fullPath = path.resolve(currentPath, item)

			if fs.isdir(fullPath) then
				scanRecursive(fullPath, visited)
			elseif string.find(fullPath, pattern) then
				results[#results + 1] = path.relative(cwd, fullPath)
			end
		end
	end

	if fs.exists(cwd) and fs.isdir(cwd) then
		scanRecursive(cwd, {})
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
function fs.delete(p)
	os.remove(p)
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
		process.spawn("mkdir", { p })
	else
		process.spawn("mkdir", { "-p", p })
	end
end

---@param src string
---@param dest string
function fs.mklink(src, dest)
	if isWindows then
		process.spawn("mklink", { "/D", dest, src })
	else
		process.spawn("ln", { "-s", src, dest })
	end
end

function fs.cwd()
	local ok, out = process.exec("pwd")
	if not ok then
		error("Failed to get current working directory")
	end

	return out:gsub("\n$", "")
end

---@param path string
function fs.listdir(path)
	local success, output = process.exec("ls", { "-1", path })
	if success then
		local files = {}
		for line in output:gmatch("[^\n]+") do
			table.insert(files, line)
		end
		return files
	else
		return {}
	end
end

---@param path string
function fs.isdir(path)
	if isWindows then
		local _, output = process.exec("cmd", { "/c", 'if exist "' .. path .. '\\*" (echo yes) else (echo no)' })
		return output:match("yes") ~= nil
	else
		local success, _ = process.exec("test", { "-d", path })
		return success == true
	end
end

---@param src string
---@param dest string
function fs.copy(src, dest)
	if isWindows then
		process.spawn("xcopy", { "/E", "/I", src, dest })
	else
		process.spawn("cp", { "-r", src, dest })
	end
end

---@param src string
---@param dest string
function fs.move(src, dest)
	if isWindows then
		process.spawn("move", { src, dest })
	else
		process.spawn("mv", { src, dest })
	end
end

return fs
