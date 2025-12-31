local bundler = {}

function read(cmd)
	local handle = io.popen(cmd, "r")
	local output = handle:read("*a")
	handle:close()
	return output
end

function write(cmd, data)
	local handle = io.popen(cmd, "w")
	handle:write(data)
	return handle:close()
end

local libs = read("pkg-config --libs luajit"):gsub("\n", "")
local cflags = read("pkg-config --cflags luajit"):gsub("\n", "")

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

---@param main string
---@param files { path: string, content: string }[]
---@return string
function bundler.compile(main, files)
	local outPath = os.tmpname()

	local filePreloads = {}
	for i, file in ipairs(files) do
		local escapedCode = file.content:gsub(".", CEscapes)
		local escapedName = file.path:gsub(".", CEscapes)

		filePreloads[i] = ('luaL_loadbuffer(L, "%s", %d, "%s"); lua_setfield(L, -2, "%s");'):format(
			escapedCode,
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
			luaL_traceback(L, L, lua_tostring(L, 1), 1);
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

			lua_pushcfunction(L, traceback);
			lua_insert(L, -(argc));

			int result = lua_pcall(L, argc - 1, 0, -(argc) - 1);
			if (result != LUA_OK) {
				fprintf(stderr, "%s\n", lua_tostring(L, -1));
				lua_close(L);
				return 1;
			}

			lua_close(L);
			return 0;
		}
	]]

	assert(write(("cc %s -xc - -o %s %s"):format(cflags, outPath, libs), code), "Compilation failed")

	return outPath
end

return bundler
