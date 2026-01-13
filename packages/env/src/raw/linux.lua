local ffi = require("ffi")

ffi.cdef([[
	char* getenv(const char* name);
	char* getcwd(char* buf, size_t size);
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

function env.tmpdir()
	return env.var("TMPDIR") or "/tmp"
end

function env.cwd()
	local buf = ffi.new("char[?]", 1024)
	local size = ffi.C.getcwd(buf, 1024)
	if size == nil then
		return nil
	end

	return ffi.string(buf, size)
end

return env
