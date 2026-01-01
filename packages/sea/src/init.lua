local sea = {}

local fs = require("fs")
local process = require("process")
local path = require("path")

local libs, cflags
if process.platform == "linux" then
	local ok, rawlibs = process.exec("pkg-config", { "--libs", "luajit" })
	if not ok or string.find(rawlibs, "luajit was not found", 1, true) then
		error("Epically failed to find luajit")
	end

	local ok, rawcflags = process.exec("pkg-config", { "--cflags", "luajit" })
	if not ok then
		error("Failed to find cflags for luajit " .. rawcflags)
	end

	libs = rawlibs:gsub("%s+$", "")
	cflags = rawcflags:gsub("%s+$", "")
elseif process.platform == "win32" then
	-- Currently hardcoded to the location of winget's LuaJIT distribution since it doesnt provide a pc.
	local ljPath = path.join(os.getenv("LOCALAPPDATA"), "Programs", "LuaJIT")
	libs = "-L" .. path.join(ljPath, "bin") .. " -llua51"
	cflags = "-I" .. path.join(ljPath, "include")
else
	error("Unsupported platform: " .. process.platform)
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
	local outPath = fs.tmpfile()

	local filePreloads = {}
	for i, file in ipairs(files) do
		-- local bytecode = sea.bytecode(file.content, file.path)
		-- local literalArray = {}
		-- for j = 1, #bytecode do literalArray[j] = string.format("%d", string.byte(bytecode, j)) end
		-- local bytecodeArray = table.concat(literalArray, ",")

		local escapedName = file.path:gsub(".", CEscapes)

		-- Bytecode temporarily disabled as windows has some issues with it apparently
		-- filePreloads[i] = ('const unsigned char data_%d[] = {%s}; luaL_loadbuffer(L, (const char*)data_%d, %d, "%s"); lua_setfield(L, -2, "%s");')
		-- 	:format(
		-- 		i,
		-- 		bytecodeArray,
		-- 		i,
		-- 		#bytecode,
		-- 		escapedName,
		-- 		escapedName
		-- 	)
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

	-- Use unsafe mode to pass the full cc command without extra escaping
	local ccCommand = "cc " .. cflags .. " -xc - -o " .. outPath .. " " .. libs
	local success, output = process.exec(ccCommand, nil, { stdin = code, unsafe = true })

	if not success or string.find(output, "is not recognized as an internal", 1, true) then
		error("Compilation failed: " .. output)
	end

	return outPath
end

return sea
