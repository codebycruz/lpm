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

return fs
