local path = require("path")

---@class fs.raw
---@field exists fun(p: string): boolean
---@field isdir fun(p: string): boolean
---@field islink fun(p: string): boolean
---@field isfile fun(p: string): boolean
---@field readdir fun(p: string): (fun(): fs.DirEntry?)?
---@field mkdir fun(p: string): boolean
---@field mklink fun(src: string, dest: string): boolean

---@alias fs.DirEntry.Type "file" | "dir" | "symlink" | "unknown"

---@class fs.DirEntry
---@field name string
---@field type fs.DirEntry.Type

local rawfs ---@type fs.raw
if jit.os == "Windows" then
	rawfs = require("fs.raw.windows")
elseif jit.os == "Linux" then
	rawfs = require("fs.raw.linux")
else
	error("Unsupported OS: " .. jit.os)
end

---@class fs: fs.raw
local fs = {}

for k, v in pairs(rawfs) do
	fs[k] = v
end

---@param p string
---@return string|nil
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
---@return boolean
function fs.write(p, content)
	local file = io.open(p, "w")
	if not file then
		return false
	end

	file:write(content)
	file:close()

	return true
end

---@param src string
---@param dest string
function fs.copy(src, dest)
	local content = fs.read(src)
	if content == nil then
		return false
	end

	local success = fs.write(dest, content)
	if not success then
		return false
	end

	return true
end

---@param old string
---@param new string
function fs.move(old, new)
	local success = fs.copy(old, new)
	if not success then
		return false
	end

	fs.delete(old)
	return true
end

---@param p string
function fs.delete(p)
	return os.remove(p) ~= nil
end

local sep = string.sub(package.config, 1, 1)

---@param glob string
function fs.globToPattern(glob)
	local pattern = glob
		:gsub("([%^%$%(%)%%%.%[%]%+%-])", "%%%1")
		:gsub("%*%*", "\001")
		:gsub("%*", "[^" .. sep .. "]*")
		:gsub("%?", "[^" .. sep .. "]")
		:gsub("\001", ".*")

	return "^" .. pattern .. "$"
end

---@param cwd string
---@param glob string
---@param opts { absolute: boolean }?
---@return string[]?
function fs.scan(cwd, glob, opts)
	if not fs.isdir(cwd) then
		error("not a directory: '" .. cwd .. "'")
	end

	local absolute = opts and opts.absolute or false

	local pattern = fs.globToPattern(glob)
	local entries = {}

	local function dir(p)
		local dirIter = fs.readdir(p)
		if not dirIter then
			return
		end

		for entry in dirIter do
			local entryPath = p .. sep .. entry.name

			if fs.isdir(entryPath) then
				dir(entryPath)
			elseif fs.isfile(entryPath) then
				if string.find(entryPath, pattern) then
					if absolute then
						entries[#entries + 1] = entryPath
					else
						entries[#entries + 1] = path.relative(cwd, entryPath)
					end
				end
			end
		end
	end

	if not fs.isdir(cwd) then
		return nil
	end

	dir(cwd)
	return entries
end

return fs
