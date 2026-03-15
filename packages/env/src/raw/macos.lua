local ffi = require("ffi")

---@class env.raw.macos: env.raw.posix
local env = require("env.raw.posix")

ffi.cdef([[
	int _NSGetExecutablePath(char* buf, uint32_t* bufsize);
]])

function env.execPath()
	local size = ffi.new("uint32_t[1]", 4096)
	local buf = ffi.new("char[?]", size[0])
	if ffi.C._NSGetExecutablePath(buf, size) ~= 0 then
		return nil
	end

	return ffi.string(buf)
end

return env
