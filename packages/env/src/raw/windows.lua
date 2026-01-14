local ffi = require("ffi")

ffi.cdef([[
	DWORD GetEnvironmentVariableA(const char* lpName, char* lpBuffer, DWORD nSize);
	DWORD GetCurrentDirectoryA(DWORD nBufferLength, char* lpBuffer);
]])

local kernel32 = ffi.load("kernel32")

local env = {}

---@param name string
function env.var(name) ---@return string?
	local bufSize = 1024
	local buf = ffi.new("char[?]", bufSize)
	local len = kernel32.GetEnvironmentVariableA(name, buf, bufSize)

	if len == 0 then
		return nil
	end

	if len > bufSize then
		bufSize = len
		buf = ffi.new("char[?]", bufSize)
		len = kernel32.GetEnvironmentVariableA(name, buf, bufSize)
		if len == 0 then
			return nil
		end
	end

	return ffi.string(buf, len)
end

function env.tmpdir()
	return env.var("TEMP") or env.var("TMP") or "C:\\Windows\\Temp"
end

function env.cwd()
	local buf = ffi.new("char[?]", 4096)
	local len = kernel32.GetCurrentDirectoryA(4096, buf)

	if len == 0 then
		return nil
	end

	return ffi.string(buf, len)
end

return env
