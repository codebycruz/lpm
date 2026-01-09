local fs = {}

local path = require("path")
local process = require("process")

local isWindows = path.separator == "\\"

---@param glob string
function fs.globToPattern(glob)
	local pattern = glob
		:gsub("([%^%$%(%)%%%.%[%]%+%-])", "%%%1")
		:gsub("%*%*", "\001")
		:gsub("%*", "[^" .. path.separator .. "]*")
		:gsub("%?", "[^" .. path.separator .. "]")
		:gsub("\001", ".*")

	return "^" .. pattern .. "$"
end

function fs.tmpfile()
	return os.tmpname()
end

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

	local function scanRecursive(currentPath)
		local items = fs.listdir(currentPath)
		if not items then return end

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
function fs.delete(p)
	os.remove(p)
end

---@param p string
function fs.exists(p)
	if isWindows then
		local _, output = process.exec("cmd", { "/c", 'if exist "' .. p .. '" (echo yes) else (echo no)' },
			{ unsafe = true })
		return output:match("yes") ~= nil
	else
		local success, _ = process.exec("test", { "-e", p })
		return success == true
	end
end

---@param p string
function fs.mkdir(p)
	if isWindows then
		process.exec("md", { p })
	else
		process.spawn("mkdir", { "-p", p })
	end
end

---@param src string
---@param dest string
function fs.mklink(src, dest)
	if isWindows then
		local cmd = "New-Item -ItemType Junction -Path '" .. dest .. "' -Target " .. src .. " -Force 2>$null"
		process.spawn("powershell", { "-NoProfile", "-Command", cmd })
	else
		process.spawn("ln", { "-s", src, dest })
	end
end

function fs.cwd()
	if isWindows then
		local ok, out = process.exec("cd")
		if not ok then
			error("Failed to get current working directory")
		end

		return out:gsub("\r?\n$", "")
	else
		local ok, out = process.exec("pwd")
		if not ok then
			error("Failed to get current working directory")
		end

		return out:gsub("\n$", "")
	end
end

---@param p string
function fs.listdir(p)
	if isWindows then
		local success, output = process.exec("dir", { "/b", p }, { unsafe = true })
		if success then
			local files = {}
			for line in output:gmatch("[^\r\n]+") do
				table.insert(files, line)
			end
			return files
		else
			return {}
		end
	else
		local success, output = process.exec("ls", { "-1", p })
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
end

---@param p string
function fs.isdir(p)
	if isWindows then
		local _, output = process.exec("cmd", { "/c", 'if exist "' .. p .. '\\*" (echo yes) else (echo no)' },
			{ unsafe = true })
		return output:match("yes") ~= nil
	else
		local success, _ = process.exec("test", { "-d", p })
		return success == true
	end
end

---@param p string
function fs.islink(p)
	if isWindows then
		local _, output = process.exec("cmd", { "/c", 'dir "' .. p .. '" | find "SYMLINK"' })
		return output ~= ""
	else
		local success, _ = process.exec("test", { "-L", p })
		return success == true
	end
end

---@param src string
---@param dest string
function fs.copy(src, dest)
	if isWindows then
		process.spawn("xcopy", { src, dest, "/E", "/I", "/Y" }, { unsafe = true })
	else
		process.spawn("cp", { "-r", src, dest })
	end
end

---@param src string
---@param dest string
function fs.move(src, dest)
	if isWindows then
		process.exec("move", { src, dest })
	else
		process.spawn("mv", { src, dest })
	end
end

return fs
