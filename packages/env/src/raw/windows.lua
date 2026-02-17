local ffi = require("ffi")

ffi.cdef([[
	typedef void* HANDLE;
	typedef uint32_t DWORD;
	typedef uint16_t WORD;
	typedef unsigned char BYTE;
	typedef int BOOL;

	DWORD GetEnvironmentVariableA(const char* lpName, char* lpBuffer, DWORD nSize);
	BOOL SetEnvironmentVariableA(const char* lpName, const char* lpValue);
	DWORD GetCurrentDirectoryA(DWORD nBufferLength, char* lpBuffer);
	DWORD GetModuleFileNameA(void* hModule, char* lpFilename, DWORD nSize);

	int _putenv_s(const char* name, const char* value);
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

---@param name string
---@param value string?
function env.set(name, value) ---@return boolean
	local result = kernel32.SetEnvironmentVariableA(name, value)
	-- Also update the CRT environment so os.getenv() stays in sync
	ffi.C._putenv_s(name, value or "")
	return result ~= 0
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

function env.execPath()
	local buf = ffi.new("char[?]", 4096)
	local len = kernel32.GetModuleFileNameA(nil, buf, 4096)

	if len == 0 then
		return nil
	end

	return ffi.string(buf, len)
end

return env
