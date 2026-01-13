local ffi = require("ffi")

ffi.cdef([[
	typedef struct __dirstream DIR;
	DIR *opendir(const char *name);
	int closedir(DIR *dirp);
	struct dirent {
		unsigned long  d_ino;
		unsigned long  d_off;
		unsigned short d_reclen;
		unsigned char  d_type;
		char           d_name[256];
	};
	struct dirent *readdir(DIR *dirp);
	int stat(const char *pathname, struct stat *statbuf);
	int lstat(const char *pathname, struct stat *statbuf);
	struct stat {
		unsigned long st_dev;
		unsigned long st_ino;
		unsigned long st_nlink;
		unsigned int  st_mode;
		unsigned int  st_uid;
		unsigned int  st_gid;
		unsigned int  __pad0;
		unsigned long st_rdev;
		long          st_size;
		long          st_blksize;
		long          st_blocks;
		unsigned long st_atime;
		unsigned long st_atime_nsec;
		unsigned long st_mtime;
		unsigned long st_mtime_nsec;
		unsigned long st_ctime;
		unsigned long st_ctime_nsec;
		long          __unused[3];
	};
	int mkdir(const char *pathname, unsigned int mode);
	int symlink(const char *target, const char *linkpath);
	char *getcwd(char *buf, size_t size);
]])

---@class fs.raw.linux
local fs = {}

---@type table<number, fs.DirEntry.Type>
local entryTypeMap = {
	[0] = "unknown",
	[4] = "dir",
	[8] = "file",
	[10] = "symlink",
}

---@param p string
---@return (fun(): fs.DirEntry?)?
function fs.readdir(p)
	local dir = ffi.C.opendir(p)
	if dir == nil then
		return nil
	end

	return function()
		while true do
			local entry = ffi.C.readdir(dir)
			if entry == nil then
				ffi.C.closedir(dir)
				return nil
			end

			local name = ffi.string(entry.d_name)
			if name ~= ".." and name ~= "." then
				return {
					name = name,
					type = entryTypeMap[entry.d_type] or "unknown",
				}
			end
		end
	end
end

local newStat = ffi.typeof("struct stat")

local function stat(p) ---@return { st_mode: number }?, number?
	local statbuf = newStat()
	if ffi.C.stat(p, statbuf) ~= 0 then
		return nil, ffi.errno()
	end

	return statbuf
end

local function lstat(p) ---@return { st_mode: number }?, number?
	local statbuf = newStat()
	if ffi.C.lstat(p, statbuf) ~= 0 then
		return nil, ffi.errno()
	end

	return statbuf
end

---@param p string
---@return boolean
function fs.exists(p)
	return stat(p) ~= nil
end

---@param p string
function fs.isdir(p)
	local s = stat(p)
	if s == nil then
		return false
	end

	return bit.band(s.st_mode, 0x4000) ~= 0
end

---@param p string
function fs.mkdir(p)
	return ffi.C.mkdir(p, 511) == 0
end

---@param src string
---@param dest string
function fs.mklink(src, dest)
	return ffi.C.symlink(src, dest) == 0
end

---@param p string
function fs.islink(p)
	local s = lstat(p)
	if s == nil then
		return false
	end

	return bit.band(s.st_mode, 0xA000) ~= 0
end

---@param p string
function fs.isfile(p)
	local s = stat(p)
	if s == nil then
		return false
	end

	return bit.band(s.st_mode, 0x8000) ~= 0
end

---@return string?
function fs.cwd()
	local buf = ffi.new("char[?]", 4096)

	local result = ffi.C.getcwd(buf, 4096)
	if result == nil then
		return nil
	end

	return ffi.string(buf)
end

return fs
