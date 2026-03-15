local ffi = require("ffi")

---@class env.raw.linux: env.raw.posix
local env = require("env.raw.posix")

ffi.cdef([[
	ssize_t readlink(const char* path, char* buf, size_t bufsiz);
]])

function env.execPath()
	local buf = ffi.new("char[?]", 4096)
	local len = ffi.C.readlink("/proc/self/exe", buf, 4096)
	if len == -1 then
		return nil
	end

	return ffi.string(buf, len)
end

return env
