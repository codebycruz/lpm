local ffi = require("ffi")

ffi.cdef([[
	typedef void* HANDLE;
	typedef uint32_t DWORD;
	typedef uint16_t WORD;
	typedef unsigned char BYTE;
	typedef int BOOL;

	typedef struct {
		DWORD dwLowDateTime;
		DWORD dwHighDateTime;
	} FILETIME;

	typedef struct {
		DWORD dwFileAttributes;
		FILETIME ftCreationTime;
		FILETIME ftLastAccessTime;
		FILETIME ftLastWriteTime;
		DWORD nFileSizeHigh;
		DWORD nFileSizeLow;
		DWORD dwReserved0;
		DWORD dwReserved1;
		char cFileName[260];
		char cAlternateFileName[14];
	} WIN32_FIND_DATAA;

	HANDLE FindFirstFileA(const char* lpFileName, WIN32_FIND_DATAA* lpFindFileData);
	BOOL FindNextFileA(HANDLE hFindFile, WIN32_FIND_DATAA* lpFindFileData);
	BOOL FindClose(HANDLE hFindFile);
	BOOL CreateDirectoryA(const char* lpPathName, void* lpSecurityAttributes);
	BOOL CreateSymbolicLinkA(const char* lpSymlinkFileName, const char* lpTargetFileName, DWORD dwFlags);
	DWORD GetFileAttributesA(const char* lpFileName);

	typedef struct {
		DWORD dwFileAttributes;
		FILETIME ftCreationTime;
		FILETIME ftLastAccessTime;
		FILETIME ftLastWriteTime;
		DWORD nFileSizeHigh;
		DWORD nFileSizeLow;
	} WIN32_FILE_ATTRIBUTE_DATA;

	BOOL GetFileAttributesExA(const char* lpFileName, int fInfoLevelClass, WIN32_FILE_ATTRIBUTE_DATA* lpFileInformation);
]])

local kernel32 = ffi.load("kernel32")

local INVALID_HANDLE_VALUE = ffi.cast("HANDLE", -1)
local INVALID_FILE_ATTRIBUTES = 0xFFFFFFFF
local FILE_ATTRIBUTE_DIRECTORY = 0x10
local FILE_ATTRIBUTE_REPARSE_POINT = 0x400

---@class fs.raw.windows
local fs = {}

---@param p string
---@return (fun(): fs.DirEntry?)?
function fs.readdir(p)
	local searchPath = p .. "\\*"

	---@type { cFileName: string, dwFileAttributes: number }
	local findData = ffi.new("WIN32_FIND_DATAA")

	local handle = kernel32.FindFirstFileA(searchPath, findData)
	if handle == INVALID_HANDLE_VALUE then
		return nil
	end

	local first = true

	return function()
		while true do
			local hasNext
			if first then
				first = false
				hasNext = true
			else
				hasNext = kernel32.FindNextFileA(handle, findData) ~= 0
			end

			if not hasNext then
				kernel32.FindClose(handle)
				return nil
			end

			local name = ffi.string(findData.cFileName)
			if name ~= "." and name ~= ".." then
				local isDir = bit.band(findData.dwFileAttributes, FILE_ATTRIBUTE_DIRECTORY) ~= 0
				local isLink = bit.band(findData.dwFileAttributes, FILE_ATTRIBUTE_REPARSE_POINT) ~= 0

				local entryType
				if isLink then
					entryType = "symlink"
				elseif isDir then
					entryType = "dir"
				else
					entryType = "file"
				end

				return {
					name = name,
					type = entryType,
				}
			end
		end
	end
end

---@param p string
---@return number?
local function getFileAttrs(p)
	local attrs = kernel32.GetFileAttributesA(p)
	if attrs == INVALID_FILE_ATTRIBUTES then
		return nil
	end
	return attrs
end

---@param p string
---@return boolean
function fs.exists(p)
	return getFileAttrs(p) ~= nil
end

---@param p string
function fs.isdir(p)
	local attrs = getFileAttrs(p)
	if attrs == nil then
		return false
	end

	return bit.band(attrs, FILE_ATTRIBUTE_DIRECTORY) ~= 0
end

---@param p string
function fs.mkdir(p)
	return kernel32.CreateDirectoryA(p, nil) ~= 0
end

---@param src string
---@param dest string
function fs.mklink(src, dest)
	local flags = fs.isdir(src) and 1 or 0
	return kernel32.CreateSymbolicLinkA(dest, src, flags) ~= 0
end

---@param p string
function fs.islink(p)
	local attrs = getFileAttrs(p)
	if attrs == nil then
		return false
	end

	return bit.band(attrs, FILE_ATTRIBUTE_REPARSE_POINT) ~= 0
end

---@param p string
function fs.isfile(p)
	local attrs = getFileAttrs(p)
	if attrs == nil then
		return false
	end

	return bit.band(attrs, FILE_ATTRIBUTE_DIRECTORY) == 0 and bit.band(attrs, FILE_ATTRIBUTE_REPARSE_POINT) == 0
end

-- FILETIME is 100ns intervals since 1601-01-01. Unix epoch is 1970-01-01.
-- Difference: 11644473600 seconds = 116444736000000000 in 100ns units.
local EPOCH_DIFF = 116444736000000000ULL

---@param ft { dwLowDateTime: number, dwHighDateTime: number }
local function filetimeToUnix(ft)
	local ticks = ffi.cast("uint64_t", ft.dwHighDateTime) * 0x100000000ULL + ft.dwLowDateTime
	return tonumber((ticks - EPOCH_DIFF) / 10000000ULL)
end

---@param attrs number
---@return fs.Stat.Type
local function attrsToType(attrs)
	if bit.band(attrs, FILE_ATTRIBUTE_REPARSE_POINT) ~= 0 then
		return "symlink"
	elseif bit.band(attrs, FILE_ATTRIBUTE_DIRECTORY) ~= 0 then
		return "dir"
	else
		return "file"
	end
end

---@class fs.raw.windows.Stat
---@field dwFileAttributes number
---@field ftLastAccessTime { dwLowDateTime: number, dwHighDateTime: number }
---@field ftLastWriteTime { dwLowDateTime: number, dwHighDateTime: number }
---@field nFileSizeHigh number
---@field nFileSizeLow number

---@type fun(): fs.raw.windows.Stat
---@diagnostic disable-next-line: assign-type-mismatch
local newFileAttrData = ffi.typeof("WIN32_FILE_ATTRIBUTE_DATA")

---@param s fs.raw.windows.Stat
local function fileSize(s)
	return tonumber(s.nFileSizeHigh) * 0x100000000 + tonumber(s.nFileSizeLow)
end

---@param s fs.raw.windows.Stat
---@param type fs.Stat.Type
---@return fs.Stat
local function rawToCrossStat(s, type)
	return {
		size = fileSize(s),
		accessTime = filetimeToUnix(s.ftLastAccessTime),
		modifyTime = filetimeToUnix(s.ftLastWriteTime),
		type = type,
	}
end

---@param p string
---@return fs.Stat?
function fs.stat(p)
	local data = newFileAttrData()
	if kernel32.GetFileAttributesExA(p, 0, data) == 0 then
		return nil
	end

	local type = bit.band(data.dwFileAttributes, FILE_ATTRIBUTE_DIRECTORY) ~= 0 and "dir" or "file"
	return rawToCrossStat(data, type)
end

---@param p string
---@return fs.Stat?
function fs.lstat(p)
	local data = newFileAttrData()
	if kernel32.GetFileAttributesExA(p, 0, data) == 0 then
		return nil
	end

	return rawToCrossStat(data, attrsToType(data.dwFileAttributes))
end

return fs
