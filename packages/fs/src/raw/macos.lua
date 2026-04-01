local ffi = require("ffi")

ffi.cdef([[
	struct timespec {
		long tv_sec;
		long tv_nsec;
	};

	struct stat {
		int32_t         st_dev;
		uint16_t        st_mode;
		uint16_t        st_nlink;
		uint64_t        st_ino;
		uint32_t        st_uid;
		uint32_t        st_gid;
		int32_t         st_rdev;
		struct timespec st_atimespec;
		struct timespec st_mtimespec;
		struct timespec st_ctimespec;
		struct timespec st_birthtimespec;
		int64_t         st_size;
		int64_t         st_blocks;
		int32_t         st_blksize;
		uint32_t        st_flags;
		uint32_t        st_gen;
		int32_t         st_lspare;
		int64_t         st_qspare[2];
	};

	struct dirent {
		uint64_t d_ino;
		uint64_t d_seekoff;
		uint16_t d_reclen;
		uint16_t d_namlen;
		uint8_t  d_type;
		char     d_name[1024];
	};
]])

pcall(ffi.cdef, [[
	int kqueue(void);
	typedef int64_t intptr_t;
	typedef uint64_t uintptr_t;

	struct kevent {
		uintptr_t ident;
		int16_t   filter;
		uint16_t  flags;
		uint32_t  fflags;
		intptr_t  data;
		void*     udata;
	};

	struct timespec_kq {
		long tv_sec;
		long tv_nsec;
	};

	int kevent(int kq, const struct kevent* changelist, int nchanges,
	           struct kevent* eventlist, int nevents, const struct timespec_kq* timeout);

	int open(const char* path, int oflag, ...);
	int close(int fd);
]])

local O_EVTONLY    = 0x8000
local EVFILT_VNODE = -4
local EV_ADD    = 0x0001
local EV_ENABLE = 0x0004
local EV_CLEAR  = 0x0020
local NOTE_WRITE  = 0x00000002
local NOTE_DELETE = 0x00000001
local NOTE_RENAME = 0x00000020
local NOTE_ATTRIB = 0x00000008

---@class fs.raw.macos: fs.raw.posix
local fs = require("fs.raw.posix")(function(s, modeToStatType)
	return {
		size = s.st_size,
		modifyTime = s.st_mtimespec.tv_sec,
		accessTime = s.st_atimespec.tv_sec,
		type = modeToStatType[bit.band(s.st_mode, 0xF000)],
		mode = bit.band(s.st_mode, 0x1FF)
	}
end)

---@alias fs.WatchEvent "create" | "modify" | "delete" | "rename"

---@class fs.Watcher
---@field close fun()
---@field poll fun()
---@field wait fun()

--- Watch a path for changes. Calls callback(event, name) for each change.
--- Returns a watcher with :poll() (non-blocking), :wait() (blocking), and :close().
---@param p string
---@param callback fun(event: fs.WatchEvent, name: string)
---@return fs.Watcher?
function fs.watch(p, callback)
	local kq = ffi.C.kqueue()
	if kq < 0 then return nil end

	local isDir = fs.isdir(p)

	local change = ffi.new("struct kevent[1]")
	local function register(fd)
		change[0].ident  = fd
		change[0].filter = EVFILT_VNODE
		change[0].flags  = bit.bor(EV_ADD, EV_ENABLE, EV_CLEAR)
		change[0].fflags = bit.bor(NOTE_WRITE, NOTE_DELETE, NOTE_RENAME, NOTE_ATTRIB)
		change[0].data   = 0
		change[0].udata  = nil
		ffi.C.kevent(kq, change, 1, nil, 0, nil)
	end

	local dirfd = ffi.C.open(p, O_EVTONLY)
	if dirfd < 0 then ffi.C.close(kq); return nil end
	register(dirfd)

	-- fd -> name map for file watches inside a directory
	local filefds = {} ---@type table<number, string>  fd -> filename

	local function watchFile(name)
		local fd = ffi.C.open(p .. "/" .. name, O_EVTONLY)
		if fd >= 0 then
			register(fd)
			filefds[tonumber(fd)] = name
		end
	end

	local prev ---@type table<string, boolean>?
	if isDir then
		prev = {}
		local iter = fs.readdir(p)
		if iter then
			for entry in iter do
				prev[entry.name] = true
				watchFile(entry.name)
			end
		end
	end

	local events = ffi.new("struct kevent[16]")
	local zero = ffi.new("struct timespec_kq[1]", {{0, 0}})

	local function process(n)
		for i = 0, n - 1 do
			local ident = tonumber(events[i].ident)
			local ff    = events[i].fflags

			if ident == tonumber(dirfd) then
				-- Event on the directory itself
				if isDir and bit.band(ff, NOTE_WRITE) ~= 0 then
					local curr = {}
					local iter = fs.readdir(p)
					if iter then for entry in iter do curr[entry.name] = true end end
					for name in pairs(curr) do
						if not prev[name] then
							callback("create", name)
							watchFile(name)
						end
					end
					for name in pairs(prev) do
						if not curr[name] then callback("delete", name) end
					end
					prev = curr
				end
				if bit.band(ff, NOTE_DELETE) ~= 0 then callback("delete", p)
				elseif bit.band(ff, NOTE_RENAME) ~= 0 then callback("rename", p) end
			else
				-- Event on a watched file inside the directory
				local name = filefds[ident]
				if name then
					if bit.band(ff, NOTE_WRITE) ~= 0 or bit.band(ff, NOTE_ATTRIB) ~= 0 then
						callback("modify", name)
					end
					if bit.band(ff, NOTE_DELETE) ~= 0 or bit.band(ff, NOTE_RENAME) ~= 0 then
						ffi.C.close(ident)
						filefds[ident] = nil
					end
				elseif not isDir then
					if bit.band(ff, NOTE_WRITE) ~= 0 or bit.band(ff, NOTE_ATTRIB) ~= 0 then
						callback("modify", p)
					end
					if bit.band(ff, NOTE_DELETE) ~= 0 then callback("delete", p)
					elseif bit.band(ff, NOTE_RENAME) ~= 0 then callback("rename", p) end
				end
			end
		end
	end

	---@type fs.Watcher
	local watcher = {}

	function watcher.poll()
		local n = ffi.C.kevent(kq, nil, 0, events, 16, zero)
		process(n)
	end

	function watcher.wait()
		-- nil timeout = block indefinitely until an event arrives
		local n = ffi.C.kevent(kq, nil, 0, events, 16, nil)
		process(n)
	end

	function watcher.close()
		for fd in pairs(filefds) do ffi.C.close(fd) end
		ffi.C.close(dirfd)
		ffi.C.close(kq)
	end

	return watcher
end

return fs
