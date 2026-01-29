local ffi = require("ffi")

ffi.cdef([[
	char* getenv(const char* name);
	int setenv(const char* name, const char* value, int overwrite);
	char* getcwd(char* buf, size_t size);
	ssize_t readlink(const char* path, char* buf, size_t bufsiz);
]])

local env = {}

---@param name string
function env.var(name) ---@return string?
	local v = ffi.C.getenv(name)
	if v == nil then
		return nil
	end

	return ffi.string(v)
end

---@param name string
---@param value string
function env.set(name, value) ---@return boolean
	return ffi.C.setenv(name, value, 1) == 0
end

function env.tmpdir()
	return env.var("TMPDIR") or "/tmp"
end

function env.cwd()
	local buf = ffi.new("char[?]", 4096)

	local result = ffi.C.getcwd(buf, 4096)
	if result == nil then
		return nil
	end

	return ffi.string(buf)
end

function env.execPath()
	local buf = ffi.new("char[?]", 4096)
	local len = ffi.C.readlink("/proc/self/exe", buf, 4096)
	if len == -1 then
		return nil
	end

	return ffi.string(buf, len)
end

return env
