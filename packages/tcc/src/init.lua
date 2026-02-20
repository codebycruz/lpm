local ffi = require("ffi")

ffi.cdef[[
	typedef struct TCCState TCCState;

	TCCState *tcc_new(void);
	void      tcc_delete(TCCState *s);

	/* Set output type: TCC_OUTPUT_MEMORY=1, TCC_OUTPUT_EXE=2,
	   TCC_OUTPUT_DLL=3, TCC_OUTPUT_OBJ=4 */
	int  tcc_set_output_type(TCCState *s, int output_type);

	/* Add include path */
	int  tcc_add_include_path(TCCState *s, const char *pathname);

	/* Add a file (C source, object, archive, or shared lib) */
	int  tcc_add_file(TCCState *s, const char *filename);

	/* Compile a string of C source code */
	int  tcc_compile_string(TCCState *s, const char *buf);

	/* Add a symbol to the compiled program */
	void tcc_add_symbol(TCCState *s, const char *name, const void *val);

	/* Relocate the compiled code into memory (output type must be MEMORY) */
	int  tcc_relocate(TCCState *s, void *ptr);

	/* Get the address of a compiled symbol */
	void *tcc_get_symbol(TCCState *s, const char *name);

	/* Set error/warning callback */
	void tcc_set_error_func(TCCState *s, void *error_opaque,
		void (*error_func)(void *opaque, const char *msg));

	/* Set a define */
	void tcc_define_symbol(TCCState *s, const char *sym, const char *value);

	/* Add a library path */
	int  tcc_add_library_path(TCCState *s, const char *pathname);

	/* Link with a library (e.g. "m" for -lm) */
	int  tcc_add_library(TCCState *s, const char *libraryname);

	/* Output to a file (exe/dll/obj) */
	int  tcc_output_file(TCCState *s, const char *filename);

	/* Set the path where libtcc1.a and include files are found */
	void tcc_set_lib_path(TCCState *s, const char *path);
]]

local TCC_OUTPUT_MEMORY = 1
local TCC_OUTPUT_EXE    = 2
local TCC_OUTPUT_DLL    = 3
local TCC_OUTPUT_OBJ    = 4

local TCC_RELOCATE_AUTO = ffi.cast("void *", 1)

-- Locate the shared library relative to this file's directory
local scriptDir = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])")
local isWindows = jit.os == "Windows"
local isMac     = jit.os == "OSX"
local libExt    = isWindows and "dll" or isMac and "dylib" or "so"
local libPath   = scriptDir .. "tcc." .. libExt

local lib = ffi.load(libPath)

local silentErrorCb = ffi.cast("void (*)(void *, const char *)", function() end)

---@class tcc.State
---@field _state ffi.cdata*
local State = {}
State.__index = State

--- Compile a C source string and run a named function, returning its result
--- as a LuaJIT cdata pointer. The function must have signature `void* fn(void)`.
---@param source string
---@param funcname string
---@return ffi.cdata*
function State:run(source, funcname)
	local ok = lib.tcc_compile_string(self._state, source)
	if ok ~= 0 then
		error("tcc: compile error")
	end

	ok = lib.tcc_relocate(self._state, TCC_RELOCATE_AUTO)
	if ok ~= 0 then
		error("tcc: relocate error")
	end

	local sym = lib.tcc_get_symbol(self._state, funcname)
	if sym == nil then
		error("tcc: symbol not found: " .. funcname)
	end

	return sym
end

--- Compile a C source string.
---@param source string
function State:compile(source)
	local ok = lib.tcc_compile_string(self._state, source)
	if ok ~= 0 then
		error("tcc: compile error")
	end
end

--- Relocate compiled code into memory so symbols can be resolved.
function State:relocate()
	local ok = lib.tcc_relocate(self._state, TCC_RELOCATE_AUTO)
	if ok ~= 0 then
		error("tcc: relocate error")
	end
end

--- Get the address of a symbol in the compiled code.
---@param name string
---@return ffi.cdata*
function State:symbol(name)
	local sym = lib.tcc_get_symbol(self._state, name)
	if sym == nil then
		error("tcc: symbol not found: " .. name)
	end
	return sym
end

--- Set the output type.
---@param outputType integer  1=memory, 2=exe, 3=dll, 4=obj
function State:setOutputType(outputType)
	lib.tcc_set_output_type(self._state, outputType)
end

--- Add an include path.
---@param path string
function State:addIncludePath(path)
	lib.tcc_add_include_path(self._state, path)
end

--- Add a library path.
---@param path string
function State:addLibraryPath(path)
	lib.tcc_add_library_path(self._state, path)
end

--- Link against a library (e.g. "m" for -lm).
---@param name string
function State:addLibrary(name)
	lib.tcc_add_library(self._state, name)
end

--- Define a preprocessor symbol.
---@param sym string
---@param value string?
function State:define(sym, value)
	lib.tcc_define_symbol(self._state, sym, value or nil)
end

--- Write the compiled output to a file (for exe/dll/obj output types).
---@param filename string
function State:outputFile(filename)
	local ok = lib.tcc_output_file(self._state, filename)
	if ok ~= 0 then
		error("tcc: output_file error")
	end
end

--- Free the TCC state.
function State:close()
	lib.tcc_delete(self._state)
	self._state = nil
end

local tcc = {}

tcc.OUTPUT_MEMORY = TCC_OUTPUT_MEMORY
tcc.OUTPUT_EXE    = TCC_OUTPUT_EXE
tcc.OUTPUT_DLL    = TCC_OUTPUT_DLL
tcc.OUTPUT_OBJ    = TCC_OUTPUT_OBJ

--- Create a new TCC compilation state.
---@return tcc.State
function tcc.new()
	local state = lib.tcc_new()
	if state == nil then
		error("tcc: failed to create TCC state")
	end

	lib.tcc_set_error_func(state, nil, silentErrorCb)

	-- Point TCC at our bundled libtcc1.a and include files
	lib.tcc_set_lib_path(state, scriptDir)

	-- Default to in-memory JIT execution
	lib.tcc_set_output_type(state, TCC_OUTPUT_MEMORY)

	local self = setmetatable({ _state = state }, State)

	-- Register a GC finalizer so the state is freed if the user forgets
	ffi.gc(state, function()
		if self._state ~= nil then
			lib.tcc_delete(self._state)
			self._state = nil
		end
	end)

	return self
end

return tcc
