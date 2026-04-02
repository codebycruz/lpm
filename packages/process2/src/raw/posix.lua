local ffi = require("ffi")

ffi.cdef([[
	typedef int pid_t;
	pid_t fork(void);
	int   execvp(const char* file, const char* const argv[]);
	pid_t waitpid(pid_t pid, int* status, int options);
	int   kill(pid_t pid, int sig);
	int   pipe(int pipefd[2]);
	long  read(int fd, void* buf, size_t count);
	long  write(int fd, const void* buf, size_t count);
	int   close(int fd);
	int   dup2(int oldfd, int newfd);
	int   open(const char* path, int flags, ...);
	int   setenv(const char* name, const char* value, int overwrite);
	int   chdir(const char* path);
	void  _exit(int status);
]])

local WNOHANG = 1
local SIGTERM = 15
local SIGKILL = 9
local O_WRONLY = 1

---@diagnostic disable: assign-type-mismatch # Ignore incessant ffi type cast annoyance

---@class process2.ffi.IntBox: ffi.cdata*
---@field [0] number

---@type fun(): process2.ffi.IntBox
local IntBox = ffi.typeof("int[1]")

---@class process2.ffi.PipeFds: ffi.cdata*
---@field [0] number
---@field [1] number

---@type fun(): process2.ffi.PipeFds
local PipeFds = ffi.typeof("int[2]")

---@class process2.ffi.CharBuf: ffi.cdata*
---@field [0] number

---@type fun(size: number): process2.ffi.CharBuf
local CharBuf = ffi.typeof("char[?]")

---@class process2.ffi.Argv: ffi.cdata*
---@field [0] string?

---@type fun(size: number): process2.ffi.Argv
local Argv = ffi.typeof("const char*[?]")

---@class process2.raw
local M = {}

---@param status number
---@return number?
local function decodeExit(status)
	if bit.band(status, 0x7f) == 0 then
		return bit.rshift(bit.band(status, 0xff00), 8)
	end
	return nil
end

---@param name string
---@param args string[]
---@return process2.ffi.Argv
local function makeArgv(name, args)
	local argv = Argv(#args + 2)
	argv[0] = name
	for i, a in ipairs(args) do argv[i] = a end
	argv[#args + 1] = nil
	return argv
end

--- Spawn a child process.
--- When both stdout and stderr are "pipe", stderr is merged into the stdout pipe
--- to avoid deadlocks from sequential blocking reads.
---@param name string
---@param args string[]
---@param opts { cwd: string?, env: table<string,string>?, stdin: string?, stdout: "pipe"|"inherit"|"null"?, stderr: "pipe"|"inherit"|"null"? }?
---@return { pid: number, stdoutFd: number?, stderrFd: number? }?, string?
function M.spawn(name, args, opts)
	opts              = opts or {}
	local stdoutMode  = opts.stdout or "pipe"
	local stderrMode  = opts.stderr or "pipe"
	local hasStdin    = opts.stdin ~= nil

	local mergeStderr = stdoutMode == "pipe" and stderrMode == "pipe"

	local pIn         = PipeFds()
	local pOut        = PipeFds()
	local pErr        = PipeFds()

	if hasStdin and ffi.C.pipe(pIn) ~= 0 then return nil, "pipe() failed" end
	if stdoutMode == "pipe" and ffi.C.pipe(pOut) ~= 0 then return nil, "pipe() failed" end
	if stderrMode == "pipe" and not mergeStderr
		and ffi.C.pipe(pErr) ~= 0 then
		return nil, "pipe() failed"
	end

	local pid = ffi.C.fork()
	if pid < 0 then return nil, "fork() failed" end

	if pid == 0 then
		if hasStdin then
			ffi.C.dup2(pIn[0], 0); ffi.C.close(pIn[0]); ffi.C.close(pIn[1])
		end
		if stdoutMode == "pipe" then
			ffi.C.dup2(pOut[1], 1); ffi.C.close(pOut[0]); ffi.C.close(pOut[1])
		elseif stdoutMode == "null" then
			local fd = ffi.C.open("/dev/null", O_WRONLY); ffi.C.dup2(fd, 1); ffi.C.close(fd)
		end
		if mergeStderr then
			ffi.C.dup2(1, 2)
		elseif stderrMode == "pipe" then
			ffi.C.dup2(pErr[1], 2); ffi.C.close(pErr[0]); ffi.C.close(pErr[1])
		elseif stderrMode == "null" then
			local fd = ffi.C.open("/dev/null", O_WRONLY); ffi.C.dup2(fd, 2); ffi.C.close(fd)
		end
		if opts.cwd then ffi.C.chdir(opts.cwd) end
		if opts.env then for k, v in pairs(opts.env) do ffi.C.setenv(k, v, 1) end end
		ffi.C.execvp(name, makeArgv(name, args))
		ffi.C._exit(1)
	end

	if hasStdin then ffi.C.close(pIn[0]) end
	if stdoutMode == "pipe" then ffi.C.close(pOut[1]) end
	if stderrMode == "pipe" and not mergeStderr then ffi.C.close(pErr[1]) end

	if hasStdin then
		ffi.C.write(pIn[1], opts.stdin, #opts.stdin)
		ffi.C.close(pIn[1])
	end

	return {
		pid      = tonumber(pid),
		stdoutFd = stdoutMode == "pipe" and tonumber(pOut[0]) or nil,
		stderrFd = stderrMode == "pipe" and not mergeStderr and tonumber(pErr[0]) or nil
	}
end

---@param fd number
---@return string
function M.readFd(fd)
	local buf, chunks = CharBuf(4096), {}
	while true do
		local n = ffi.C.read(fd, buf, 4096)
		if n <= 0 then break end
		chunks[#chunks + 1] = ffi.string(buf, n)
	end
	ffi.C.close(fd)
	return table.concat(chunks)
end

---@param pid number
---@return number?
function M.wait(pid)
	local st = IntBox()
	ffi.C.waitpid(pid, st, 0)
	return decodeExit(st[0])
end

---@param pid number
---@return number?
function M.poll(pid)
	local st = IntBox()
	if ffi.C.waitpid(pid, st, WNOHANG) == 0 then return nil end
	return decodeExit(st[0])
end

---@param pid number
---@param force boolean?
function M.kill(pid, force)
	ffi.C.kill(pid, force and SIGKILL or SIGTERM)
end

return M
