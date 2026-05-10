local sea = {}

local process = require("process")
local path = require("path")
local env = require("env")
local fs = require("fs")
local jit = require("jit")
local Archive = require("archive")
local curl = require("curl-sys")
local ansi = require("ansi")

local util = require("util")

local ljDistRepo = "lde-org/lj-dist"
local ljDistTag = "latest"

local function getPlatformArch()
	local platform = jit.os == "Linux" and "linux"
		or jit.os == "Windows" and "windows"
		or jit.os == "OSX" and "macos"
		or error("Unsupported platform: " .. jit.os)

	local arch = jit.arch == "x64" and "x86-64"
		or jit.arch == "arm64" and "aarch64"
		or error("Unsupported architecture: " .. jit.arch)

	return platform, arch
end

--- Parse arch and libc from a compiler's -dumpmachine output.
--- Returns nil for both if the platform doesn't use a libc triplet component (OSX, Windows).
--- On Linux, derives arch from the triplet so cross-compilers (e.g. Android NDK) work correctly.
---@param compiler string
---@return string|nil arch  -- e.g. "x86-64" or "aarch64"
---@return "musl" | "gnu" | "android" | nil libc
local function getTargetFromCompiler(compiler)
	if jit.os == "OSX" then return nil, nil end
	if jit.os == "Windows" then return nil, "gnu" end

	---@type string?
	local arch

	-- Use the compiler's -dumpmachine to get the target triplet.
	local code, out = process.exec(compiler, { "-dumpmachine" })
	if code == 0 and out and out ~= "" then
		out = out:match("^%s*(.-)%s*$")

		if out:find("^x86_64") or out:find("^x86%-64") then
			arch = "x86-64"
		elseif out:find("^aarch64") then
			arch = "aarch64"
		end

		local libc
		if out:find("android", 1, true) then
			libc = "android"
		elseif out:find("musl", 1, true) then
			libc = "musl"
		elseif out:find("gnu", 1, true) then
			libc = "gnu"
		end

		if arch and libc then
			return arch, libc
		end
	end

	local lddPatterns = { ["musl"] = "musl", ["gnu"] = "GNU libc" }

	local _, lddout = process.exec("ldd", { "--version" })
	for libc, pattern in pairs(lddPatterns) do
		if string.find(lddout or "", pattern, 1, true) then return arch, libc end
	end

	io.stderr:write("[sea] warning: could not detect target from compiler '" .. compiler .. "', defaulting to gnu\n")

	return arch, "gnu"
end

---@param compiler? string
---@return string
local function getLuajitPath(compiler)
	compiler = compiler or env.var("SEA_CC") or "gcc"

	local cacheDir = path.join(env.tmpdir(), "luajit-cache")
	local platform, hostArch = getPlatformArch()
	local compilerArch, libc = getTargetFromCompiler(compiler)
	local arch = compilerArch or hostArch

	local target = table.concat({ "libluajit", platform, arch, libc }, "-")
	local targetDir = path.join(cacheDir, target)

	if fs.exists(path.join(targetDir, "include", "lua.h")) then
		return targetDir
	end

	fs.mkdir(cacheDir)

	local tarballName = target .. ".tar.gz"
	local downloadUrl = string.format(
		"https://github.com/%s/releases/download/%s/%s",
		ljDistRepo,
		ljDistTag,
		tarballName
	)
	local tarballPath = path.join(cacheDir, tarballName)

	local bar = ansi.progress("Downloading " .. tarballName)
	local ok, dlErr = curl.download(downloadUrl, tarballPath, {
		progress = function(dltotal, dlnow)
			local ratio = dltotal > 0 and (dlnow / dltotal) or nil
			local info = dltotal > 0
				and (ansi.formatBytes(dlnow) .. " / " .. ansi.formatBytes(dltotal))
				or ansi.formatBytes(dlnow)
			bar:update(ratio, info)
		end
	})
	if not ok then
		bar:fail("Downloading " .. tarballName)
		error("Failed to download LuaJIT from " .. downloadUrl .. ": " .. (dlErr or ""))
	end
	bar:done("Downloaded " .. tarballName)

	local ok, err = Archive.new(tarballPath):extract(cacheDir)
	if not ok then
		print("??", downloadUrl, tarballPath)
		error("Failed to extract LuaJIT: " .. (err or ""))
	end

	fs.delete(tarballPath)

	return targetDir
end



sea.getLuajitPath = getLuajitPath

local CEscapes = {
	["\a"] = "\\a",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
	["\v"] = "\\v",
	['"'] = '\\"',
	["\\"] = "\\\\"
}

---Convert binary content to a C uint8_t array initialiser string, e.g. "0x41,0x42,..."
local function toByteLiteral(content)
	local t = {}
	for i = 1, #content do
		t[i] = string.format("0x%02x", string.byte(content, i))
	end
	return table.concat(t, ",")
end

---Sanitise a library name so it is safe to use as a C identifier.
local function safeIdent(name)
	return string.gsub(name, "[^%w]", "_")
end

---Build shared library extraction data (reusable by both compile and compileShared).
---@param sharedLibs { name: string, content: string }[]
---@return table data  # with keys: libDeclsStr, libStartupStr, libPreloadsStr, preloadsC, ffiShim, tmpnameShim, hasLibs
function sea.buildSharedLibData(sharedLibs)
	sharedLibs = sharedLibs or {}

	local libDecls = {}
	local libStartup = {}
	local libPreloads = {}
	local ffiShimEntries = {}

	for _, lib in ipairs(sharedLibs) do
		local id                            = safeIdent(lib.name)
		local hash                          = util.fnv1a(lib.content)
		local ext                           = jit.os == "Windows" and "dll"
			or jit.os == "OSX" and "dylib"
			or "so"
		local libFileName                   = string.format("lde-lib-%s-%s.%s", lib.name, hash, ext)
		ffiShimEntries[#ffiShimEntries + 1] = string.format('["%s"]="%s"', lib.name, libFileName)
		local leaf                          = lib.name:match("[^.]+$")
		local bare                          = leaf:match("^lib(.+)$") or leaf
		ffiShimEntries[#ffiShimEntries + 1] = string.format('["%s"]="%s"', leaf, libFileName)
		ffiShimEntries[#ffiShimEntries + 1] = string.format('["%s.%s"]="%s"', leaf, ext, libFileName)
		ffiShimEntries[#ffiShimEntries + 1] = string.format('["%s"]="%s"', bare, libFileName)

		libDecls[#libDecls + 1]             = string.format(
			"static const uint8_t %sLibrary[] = {%s};",
			id, toByteLiteral(lib.content)
		)
		libDecls[#libDecls + 1]             = string.format(
			'static const char %sLibraryName[] = "%s";',
			id, libFileName
		)
		libDecls[#libDecls + 1]             = string.format(
			"static char %sLibraryPath[4096];",
			id
		)

		libStartup[#libStartup + 1]         = string.format([[
	{
		snprintf(%sLibraryPath, sizeof(%sLibraryPath), "%%s/%%s", lde_tmpdir, %sLibraryName);
		FILE* f = fopen(%sLibraryPath, "rb");
		if (f == NULL) {
			f = fopen(%sLibraryPath, "wb");
			if (f == NULL) { perror("lde-sea: cannot write %s"); return 1; }
			fwrite(%sLibrary, 1, sizeof(%sLibrary), f);
			fclose(f);
		} else {
			fclose(f);
		}
	}]], id, id, id, id, id, lib.name, id, id)

		local luaopenSym                    = "luaopen_" .. lib.name:gsub("%.", "_")
		libPreloads[#libPreloads + 1]       = string.format([[
	lua_pushstring(L, %sLibraryPath);
	lua_pushstring(L, "%s");
	lua_pushcclosure(L, lde_loadlib_loader, 2);
	lua_setfield(L, -2, "%s");]], id, luaopenSym, string.gsub(lib.name, ".", CEscapes))
	end

	local hasLibs = #sharedLibs > 0
	local libDeclsStr = table.concat(libDecls, "\n")
	local libTmpDirInit = not hasLibs and "" or [[
char lde_tmpdir[4096];
{
#ifdef _WIN32
	const char* lde_tmp_env = getenv("TEMP");
	if (!lde_tmp_env) lde_tmp_env = getenv("TMP");
	if (!lde_tmp_env) lde_tmp_env = "C:\\Windows\\Temp";
#else
	const char* lde_tmp_env = getenv("TMPDIR");
	if (!lde_tmp_env) lde_tmp_env = "/tmp";
#endif
	snprintf(lde_tmpdir, sizeof(lde_tmpdir), "%s", lde_tmp_env);
	size_t lde_tmp_len = strlen(lde_tmpdir);
	while (lde_tmp_len > 1 && (lde_tmpdir[lde_tmp_len-1] == '/' || lde_tmpdir[lde_tmp_len-1] == '\\')) {
		lde_tmpdir[--lde_tmp_len] = '\0';
	}
}
]]
	local libStartupStr = libTmpDirInit .. table.concat(libStartup, "\n")
	local libPreloadsStr = table.concat(libPreloads, "\n")

	local tmpnameShim = util.dedent([[
		do
			local _ctr = 0
			local _tmpdir = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
			_tmpdir = _tmpdir:gsub("[\\/]+$", "")
			os.tmpname = function()
				_ctr = _ctr + 1
				return _tmpdir .. "/lde_" .. tostring(os.clock() * 1000):gsub("%.", "") .. "_" .. _ctr .. ".tmp"
			end
		end
	]])

	local ffiShim = ""
	if #ffiShimEntries > 0 then
		ffiShim = util.dedent(string.format([[
			do
				local _ffi = require("ffi")
				local _tmpdir
				if _ffi.os == "Windows" then
					_tmpdir = os.getenv("TEMP") or os.getenv("TMP") or "C:\\Windows\\Temp"
				else
					_tmpdir = os.getenv("TMPDIR") or "/tmp"
				end
				_tmpdir = _tmpdir:gsub("[\\/]+$", "")
				local _names = {%s}
				local _map = {}
				for k, v in pairs(_names) do _map[k] = _tmpdir .. "/" .. v end
				local _orig = _ffi.load
				_ffi.load = function(name, ...)
					local remap = _map[name] or _map[name:match("[^/\\]+$")]
					return _orig(remap or name, ...)
				end
			end
		]], table.concat(ffiShimEntries, ", ")))
	end

	-- C helper: lde_loadlib_loader
	local loadlibHelper = ""
	if hasLibs then
		loadlibHelper = [[
static int lde_loadlib_loader(lua_State* L) {
	const char* soPath = lua_tostring(L, lua_upvalueindex(1));
	const char* sym    = lua_tostring(L, lua_upvalueindex(2));
	lua_getglobal(L, "package");
	lua_getfield(L, -1, "loadlib");
	lua_pushstring(L, soPath);
	lua_pushstring(L, sym);
	if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
		return luaL_error(L, "loadlib failed for %s: %s", soPath, lua_tostring(L, -1));
	}
	if (lua_type(L, -1) == LUA_TFUNCTION) {
		if (lua_pcall(L, 0, 1, 0) != LUA_OK) {
			return luaL_error(L, "init failed for %s: %s", soPath, lua_tostring(L, -1));
		}
	}
	return 1;
}
]]
	end

	return {
		libDeclsStr = libDeclsStr,
		libStartupStr = libStartupStr,
		libPreloadsStr = libPreloadsStr,
		preloadsC = libPreloadsStr, -- Lua C API preload calls
		ffiShim = ffiShim,    -- Lua ffi.load shim
		tmpnameShim = tmpnameShim, -- Lua os.tmpname shim
		hasLibs = hasLibs,
		loadlibHelper = loadlibHelper
	}
end

---@param main string # name used as the chunk label
---@param source string # bundled lua source (output of bundlePackage)
---@param sharedLibs? { name: string, content: string }[]
---@param compiler? string # path to compiler binary; defaults to SEA_CC env var or "gcc"
---@return string
function sea.compile(main, source, sharedLibs, compiler)
	local outPath = path.join(env.tmpdir(), "sea.out")
	sharedLibs = sharedLibs or {}

	local data = sea.buildSharedLibData(sharedLibs)

	-- Apply ffi shim and tmpname shim to source
	if data.ffiShim ~= "" then
		source = data.ffiShim .. "\n" .. source
	end
	source = data.tmpnameShim .. "\n" .. source

	local filePreloads = {
		('luaL_loadbuffer(L, "%s", %d, "%s"); lua_setfield(L, -2, "%s");')
			:format(
				source:gsub(".", CEscapes),
				#source,
				"@" .. main:gsub(".", CEscapes),
				main:gsub(".", CEscapes)
			)
	}

	local stdintInclude = (data.hasLibs and "#include <stdint.h>\n#include <string.h>\n#include <stdlib.h>\n" or "") ..
		"#ifdef __ANDROID__\n#include <unistd.h>\n#endif\n"

	local code = stdintInclude .. [[
#include <stdio.h>
#include "lauxlib.h"
#include "lualib.h"

]] .. data.libDeclsStr .. [[

]] .. data.loadlibHelper .. [[

int traceback(lua_State* L) {
	const char* msg = lua_tostring(L, 1);
	if (msg == NULL) {
		msg = "(error object is not a string)";
	}

	luaL_traceback(L, L, msg, 1);
	return 1;
}

int main(int argc, char** argv) {
]] .. data.libStartupStr .. [[

	lua_State* L = luaL_newstate();
	luaL_openlibs(L);

	lua_getglobal(L, "package");
	lua_getfield(L, -1, "preload");

	]] .. table.concat(filePreloads, "\n\t") .. [[

	]] .. data.libPreloadsStr .. [[

	lua_getfield(L, -1, "]] .. main:gsub(".", CEscapes) .. [[");

	for (int i = 1; i < argc; i++) {
		lua_pushstring(L, argv[i]);
	}

	int base = lua_gettop(L) - (argc - 1);
	lua_pushcfunction(L, traceback);
	lua_insert(L, base);

	int result = lua_pcall(L, argc - 1, 0, base);
	if (result != LUA_OK) {
		fprintf(stderr, "%s\n", lua_tostring(L, -1));
		lua_close(L);
#ifdef __ANDROID__
		fflush(NULL);
		_exit(1);
#else
		return 1;
#endif
	}

	lua_close(L);
#ifdef __ANDROID__
	fflush(NULL);
	_exit(0);
#else
	return 0;
#endif
}
]]

	local ljPath = getLuajitPath()
	local includePath = path.join(ljPath, "include")
	local libPath = path.join(ljPath, "lib")

	local args = {
		"-I" .. includePath,
		"-xc", "-",
		"-o", outPath,
		"-xnone", path.join(libPath, "libluajit.a")
	}

	if jit.os == "Linux" then
		args[#args + 1] = "-lm"
		args[#args + 1] = "-ldl"
		args[#args + 1] = "-Wl,--export-dynamic" -- expose lua symbols for lua dependencies
	elseif jit.os == "OSX" then
		args[#args + 1] = "-Wl,-export_dynamic" -- expose lua symbols for lua dependencies
	end
	local execEnv
	if jit.os == "Windows" and compiler ~= "gcc" then
		-- compiler is a full path into mingw/bin; ensure subtools (as.exe etc) are found
		execEnv = { PATH = path.dirname(compiler) .. ";" .. (env.var("PATH") or "") }
	end
	local code, stdout, stderr = process.exec(compiler, args, { stdin = code, env = execEnv })
	if code ~= 0 or string.find(stderr or "", "is not recognized as an internal", 1, true) then
		local err = (stderr and stderr ~= "" and stderr) or (stdout and stdout ~= "" and stdout) or ""
		error("Compilation failed: " .. err)
	end

	return outPath
end

---Compile C source code into a shared library (.so / .dll / .dylib).
---@param cCode string # Complete C source code for the shared library
---@param compiler? string # path to compiler binary; defaults to SEA_CC env var or "gcc"
---@return string outPath
function sea.compileShared(cCode, compiler)
	compiler = compiler or env.var("SEA_CC") or "gcc"

	local ext = jit.os == "Windows" and "dll"
		or jit.os == "OSX" and "dylib"
		or "so"
	local outPath = path.join(env.tmpdir(), "sea-shared." .. ext)

	local ljPath = getLuajitPath()
	local includePath = path.join(ljPath, "include")
	local libPath = path.join(ljPath, "lib")

	local args = {
		"-I" .. includePath,
		"-fPIC",
		"-shared",
		"-xc", "-",
		"-o", outPath,
		"-xnone", path.join(libPath, "libluajit.a")
	}

	if jit.os == "Linux" then
		args[#args + 1] = "-lm"
		args[#args + 1] = "-ldl"
		args[#args + 1] = "-Wl,--export-dynamic"
	elseif jit.os == "OSX" then
		args[#args + 1] = "-Wl,-export_dynamic"
	end

	local execEnv
	if jit.os == "Windows" and compiler ~= "gcc" then
		execEnv = { PATH = path.dirname(compiler) .. ";" .. (env.var("PATH") or "") }
	end

	local code, stdout, stderr = process.exec(compiler, args, { stdin = cCode, env = execEnv })
	if code ~= 0 or string.find(stderr or "", "is not recognized as an internal", 1, true) then
		local err = (stderr and stderr ~= "" and stderr) or (stdout and stdout ~= "" and stdout) or ""
		error("Shared library compilation failed: " .. err)
	end

	return outPath
end

return sea
