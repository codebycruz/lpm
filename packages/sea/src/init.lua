local sea = {}

local process = require("process")
local path = require("path")
local env = require("env")
local fs = require("fs")
local jit = require("jit")

local ljDistRepo = "codebycruz/lj-dist"
local ljDistTag = "latest"

local function getPlatformArch()
	local platform = process.platform == "linux" and "linux"
		or process.platform == "win32" and "windows"
		or error("Unsupported platform: " .. process.platform)

	local arch = jit.arch == "x64" and "x86-64"
		or jit.arch == "arm64" and "aarch64"
		or error("Unsupported architecture: " .. jit.arch)

	return platform, arch
end

local function getLuajitPath()
	local cacheDir = path.join(env.tmpdir(), "luajit-cache")
	local platform, arch = getPlatformArch()
	local targetDir = path.join(cacheDir, string.format("libluajit-%s-%s", platform, arch))

	if fs.exists(path.join(targetDir, "include", "lua.h")) then
		return targetDir
	end

	fs.mkdir(cacheDir)

	local tarballName = string.format("libluajit-%s-%s.tar.gz", platform, arch)
	local downloadUrl = string.format(
		"https://github.com/%s/releases/download/%s/%s",
		ljDistRepo,
		ljDistTag,
		tarballName
	)
	local tarballPath = path.join(cacheDir, tarballName)

	local success, output = process.exec("curl", { "-L", "-o", tarballPath, downloadUrl })
	if not success then
		error("Failed to download LuaJIT from " .. downloadUrl .. ": " .. output)
	end

	local success, output = process.exec("tar", { "-xzf", tarballPath, "-C", cacheDir })
	if not success then
		error("Failed to extract LuaJIT: " .. output)
	end

	fs.delete(tarballPath)

	return targetDir
end



local CEscapes = {
	["\a"] = "\\a",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
	["\v"] = "\\v",
	['"'] = '\\"',
	["\\"] = "\\\\",
}

---@param content string
---@param chunkName string
function sea.bytecode(content, chunkName)
	local success, bytecode = process.exec("luajit", { "-b", "-g", "-F", chunkName, "-", "-" }, { stdin = content })

	if not success then
		error("Failed to compile bytecode: " .. bytecode)
	end

	return bytecode
end

---@param main string
---@param files { path: string, content: string }[]
---@return string
function sea.compile(main, files)
	local outPath = path.join(env.tmpdir(), "sea.out")

	local filePreloads = {}
	for i, file in ipairs(files) do
		local escapedName = file.path:gsub(".", CEscapes)

		filePreloads[i] = ('luaL_loadbuffer(L, "%s", %d, "%s"); lua_setfield(L, -2, "%s");')
			:format(
				file.content:gsub(".", CEscapes),
				#file.content,
				escapedName,
				escapedName
			)
	end

	local code = [[
		#include <stdio.h>
		#include "lauxlib.h"
		#include "lualib.h"

		int traceback(lua_State* L) {
			const char* msg = lua_tostring(L, 1);
			if (msg == NULL) {
				msg = "(error object is not a string)";
			}

			luaL_traceback(L, L, msg, 1);
			return 1;
		}

		int main(int argc, char** argv) {
			lua_State* L = luaL_newstate();
			luaL_openlibs(L);

			lua_getglobal(L, "package");
			lua_getfield(L, -1, "preload");

			]] .. table.concat(filePreloads, "\n") .. [[

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
				return 1;
			}

			lua_close(L);
			return 0;
		}
	]]

	local ljPath = getLuajitPath()
	local includePath = path.join(ljPath, "include")
	local libPath = path.join(ljPath, "lib")

	local args = {
		"-I" .. includePath,
		"-xc", "-",
		"-o", outPath,
		"-xnone", path.join(libPath, "libluajit.a"),
	}

	if process.platform == "linux" then
		args[#args + 1] = "-lm"
		args[#args + 1] = "-ldl"
	end

	local success, output = process.exec("gcc", args, { stdin = code })
	if not success or string.find(output, "is not recognized as an internal", 1, true) then
		error("Compilation failed: " .. output)
	end

	return outPath
end

return sea
