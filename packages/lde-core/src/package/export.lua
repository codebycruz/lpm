---@module "lde-core.package.export"

-- Parses ---@export annotations from Lua source and maps C types to FFI signatures.
-- Annotation format:
--   ---@export foo fun(a: uint32_t, b: uint32_t): uint32_t
--   ---@export fun(a: uint32_t): void          (name derived from following function)
--
-- After execution of the bundled Lua code, _G.C_EXPORTS_<name> must contain
-- a void* value pointing to the callable C function.

-- Known C types
local CTypeMap = {
	["void"]           = "void",
	["int"]            = "int",
	["unsigned int"]   = "unsigned int",
	["char"]           = "char",
	["unsigned char"]  = "unsigned char",
	["signed char"]    = "signed char",
	["short"]          = "short",
	["unsigned short"] = "unsigned short",
	["long"]           = "long",
	["unsigned long"]  = "unsigned long",
	["float"]          = "float",
	["double"]         = "double",
	["bool"]           = "bool",
	["_Bool"]          = "bool",
	["size_t"]         = "size_t",
	["ssize_t"]        = "ssize_t",
	["ptrdiff_t"]      = "ptrdiff_t",
	["intptr_t"]       = "intptr_t",
	["uintptr_t"]      = "uintptr_t",
	["int8_t"]         = "int8_t",
	["int16_t"]        = "int16_t",
	["int32_t"]        = "int32_t",
	["int64_t"]        = "int64_t",
	["uint8_t"]        = "uint8_t",
	["uint16_t"]       = "uint16_t",
	["uint32_t"]       = "uint32_t",
	["uint64_t"]       = "uint64_t",
	["const char *"]   = "const char *",
	["char *"]         = "char *",
	["void *"]         = "void *",
	["const void *"]   = "const void *"
}

---@class lde.Export
---@field name string            # Export symbol name
---@field params { name: string, type: string }[] # Parameter names and C types
---@field returnType string      # Return C type
---@field ffiSignature string    # ffi.cast-compatible function pointer signature

local Export = {}

-- Lazy mirror: any pointer type we haven't listed is treated as valid.
local isValidType = setmetatable({}, {
	---@diagnostic disable-next-line: assign-type-mismatch
	__index = function(_, k)
		return CTypeMap[k] ~= nil or k:match("%*$") ~= nil
	end
})

---@param ctype string
---@return boolean
local function knownType(ctype)
	if isValidType[ctype] then return true end
	return false
end

---@param ctype string
---@return string
local function toFFIType(ctype)
	return CTypeMap[ctype] or ctype
end

---@param ctype string
---@return boolean
local function isPointerReturn(ctype)
	return ctype:match("%*$") ~= nil
end

---@param ctype string
---@return boolean
local function isIntType(ctype)
	return ctype:find("^u?int%d+_t$")
		or ctype == "int" or ctype == "unsigned int"
		or ctype == "char" or ctype == "unsigned char" or ctype == "signed char"
		or ctype == "short" or ctype == "unsigned short"
		or ctype == "long" or ctype == "unsigned long"
		or ctype == "bool" or ctype == "_Bool"
		or ctype == "size_t" or ctype == "ssize_t"
		or ctype == "ptrdiff_t" or ctype == "intptr_t" or ctype == "uintptr_t"
end

local function isFloatType(ctype)
	return ctype == "float" or ctype == "double"
end

local function isStringType(ctype)
	return ctype == "const char *" or ctype == "char *"
end

local function isVoidType(ctype)
	return ctype == "void"
end

---Parse a single ---@export line into an export descriptor.
---Accepts:
---   ---@export foo fun(a: uint32_t, b: int): uint32_t
---   ---@export fun(a: uint32_t): void
---@param line string
---@return lde.Export?
---@return string? error
local function parseExportLine(line)
	local name, paramsStr, returnType = line:match("^%-%-%-@export%s+(%w+)%s+fun%((.*)%)%s*:%s*(.+)$")
	if not name then
		name, paramsStr, returnType = line:match("^%-%-%-@export%s+fun%((.*)%)%s*:%s*(.+)$")
	end

	if not paramsStr then
		return nil
	end

	returnType = returnType:match("^%s*(.-)%s*$")
	if not knownType(returnType) then
		return nil, "Unknown C return type: " .. returnType
	end

	local params = {}
	if paramsStr:match("%S") then
		for param in paramsStr:gmatch("[^,]+") do
			local paramName, paramType = param:match("^%s*(%w+)%s*:%s*(.+)$")
			if not paramName then
				return nil, "Invalid parameter syntax: " .. param
			end
			paramType = paramType:match("^%s*(.-)%s*$")
			if not knownType(paramType) then
				return nil, "Unknown C type for parameter '" .. paramName .. "': " .. paramType
			end
			params[#params + 1] = { name = paramName, type = paramType }
		end
	end

	local ffiParamParts = {}
	for _, p in ipairs(params) do
		ffiParamParts[#ffiParamParts + 1] = toFFIType(p.type)
	end
	local ffiSignature = toFFIType(returnType) .. "(*)(" .. table.concat(ffiParamParts, ", ") .. ")"

	return {
		name = name, -- nil if name should be derived from following function definition
		params = params,
		returnType = returnType,
		ffiSignature = ffiSignature
	}
end

---Find the function name defined after an export annotation line within source text.
---@param source string
---@param startPos number  # Position after the ---@export line
---@return string|nil funcName
local function findNextFunctionName(source, startPos)
	local tail = source:sub(startPos)
	local funcName = tail:match("^[^\r\n]*local%s+function%s+(%w+)%s*%(")
		or tail:match("^[^\r\n]*function%s+(%w+)%s*%(")
		or tail:match("^[^\r\n]*local%s+(%w+)%s*=%s*function%s*%(")
	return funcName
end

---Find the position of `end` that closes the function at the given position.
---Returns the position right after the `end` keyword.
---@param source string
---@param funcStart number  # Position at start of `function` keyword
---@return number endPos  # Position right after the matching `end`
local function findFunctionEnd(source, funcStart)
	-- Simple approach: count `function`/`then`/`do`/`repeat` as depth +1,
	-- `end`/`until` as depth -1.
	local depth = 0
	local pos = funcStart

	while pos <= #source do
		-- Find next keyword
		local nextWord, wordEnd = source:match("()(function)([^%w]|$)", pos)
		if not nextWord then nextWord, wordEnd = #source + 1, #source + 1 end
		local nextThen, thenEnd = source:match("()(then)([^%w]|$)", pos)
		if not nextThen then nextThen, thenEnd = #source + 1, #source + 1 end
		local nextDo, doEnd = source:match("()(do)([^%w]|$)", pos)
		if not nextDo then nextDo, doEnd = #source + 1, #source + 1 end
		local nextRepeat, repeatEnd = source:match("()(repeat)([^%w]|$)", pos)
		if not nextRepeat then nextRepeat, repeatEnd = #source + 1, #source + 1 end
		local nextEnd, endEnd = source:match("()(end)([^%w]|$)", pos)
		if not nextEnd then nextEnd, endEnd = #source + 1, #source + 1 end
		local nextUntil, untilEnd = source:match("()(until)([^%w]|$)", pos)
		if not nextUntil then nextUntil, untilEnd = #source + 1, #source + 1 end

		local minPos = math.min(nextWord, nextThen, nextDo, nextRepeat, nextEnd, nextUntil)
		if minPos > #source then break end

		local word
		if minPos == nextWord then
			word = "function"; pos = wordEnd
		elseif minPos == nextThen then
			word = "then"; pos = thenEnd
		elseif minPos == nextDo then
			word = "do"; pos = doEnd
		elseif minPos == nextRepeat then
			word = "repeat"; pos = repeatEnd
		elseif minPos == nextEnd then
			word = "end"; pos = endEnd
		else
			word = "until"; pos = untilEnd
		end

		if word == "function" or word == "then" or word == "do" or word == "repeat" then
			depth = depth + 1
		elseif word == "end" or word == "until" then
			depth = depth - 1
			if depth == 0 then
				return pos -- position right after `end`
			end
		end
	end

	return #source + 1
end

---Process entrypoint source: find ---@export annotations nearby function definitions,
---and inject _G.C_EXPORTS_<name> = ffi.cast("void *", ffi.cast(type, func)) code.
---@param entrypointSource string
---@return string modifiedSource
---@return lde.Export[] exports
local function processSourceWithExports(entrypointSource)
	local exports = {}
	if not entrypointSource:match("%-%-%-@export") then
		return entrypointSource, {}
	end

	-- First pass: collect all export annotations and their positions
	local annotations = {}
	for pos, line in entrypointSource:gmatch("()([^\r\n]*%-%-%-@export[^\r\n]*)") do
		local exp, err = parseExportLine(line)
		if exp then
			annotations[#annotations + 1] = { pos = pos, lineEnd = pos + #line, exp = exp }
		elseif err then
			io.stderr:write("[lde] warning: invalid ---@export: " .. err .. "\n")
		end
	end

	if #annotations == 0 then
		return entrypointSource, {}
	end

	-- Second pass: for each annotation, find the function definition that follows,
	-- determine its name (if needed), find the function end, and compute the injection.
	local injections = {} -- { injectPos -> code }
	for _, ann in ipairs(annotations) do
		local exp = ann.exp

		-- Find the function definition after the annotation
		local funcName = findNextFunctionName(entrypointSource, ann.lineEnd)
		if not funcName then
			io.stderr:write("[lde] warning: ---@export without a following function definition\n")
			goto continue
		end

		-- Determine export name
		if not exp.name then
			exp.name = funcName
		end

		-- Find start of function definition
		local funcStart = entrypointSource:find("function%s+" .. funcName:gsub("(%W)", "%%%1") .. "%s*%(", ann.lineEnd)
		if not funcStart then
			-- Try `local function name(`
			funcStart = entrypointSource:find("local%s+function%s+" .. funcName:gsub("(%W)", "%%%1") .. "%s*%(",
				ann.lineEnd)
		end
		if not funcStart then
			-- Try `local name = function(`
			funcStart = entrypointSource:find("local%s+" .. funcName:gsub("(%W)", "%%%1") .. "%s*=%s*function%s*%(",
				ann.lineEnd)
		end

		if not funcStart then
			io.stderr:write("[lde] warning: ---@export: could not find function '" .. funcName .. "' definition\n")
			goto continue
		end

		local funcEnd = findFunctionEnd(entrypointSource, funcStart)

		-- Build injection code: safe variant that stores both the callback and a void* reference
		-- The callback cdata is stored to prevent GC; the void* is what C reads.
		local cbKey = "C_EXPORTS_CB_" .. exp.name
		local ptrKey = "C_EXPORTS_" .. exp.name
		local injection = string.format(
			' _G.%s = ffi.cast("%s", %s); _G.%s = ffi.cast("void *", _G.%s)',
			cbKey, exp.ffiSignature, funcName, ptrKey, cbKey
		)

		injections[funcEnd] = (injections[funcEnd] or "") .. injection
		exports[#exports + 1] = exp

		::continue::
	end

	-- Apply injections in reverse order to preserve positions
	local sortedPositions = {}
	for pos, _ in pairs(injections) do
		sortedPositions[#sortedPositions + 1] = pos
	end
	table.sort(sortedPositions, function(a, b) return a > b end)

	local result = entrypointSource
	for _, pos in ipairs(sortedPositions) do
		result = result:sub(1, pos - 1) .. injections[pos] .. result:sub(pos)
	end

	return result, exports
end

---Generate the inline C code that pushes a C argument to the Lua stack.
---@param paramType string
---@param paramName string
---@return string
local function genPushArg(paramType, paramName)
	if isIntType(paramType) then
		return "lua_pushinteger(L, (lua_Integer)" .. paramName .. ");"
	elseif isFloatType(paramType) then
		return "lua_pushnumber(L, (lua_Number)" .. paramName .. ");"
	elseif isStringType(paramType) then
		return "lua_pushstring(L, " .. paramName .. ");"
	elseif isVoidType(paramType) then
		return "/* void param */"
	else
		return "lua_pushlightuserdata(L, (void*)(uintptr_t)" .. paramName .. ");"
	end
end

---Generate the inline C code that retrieves a return value from the Lua stack.
---@param returnType string
---@return string
local function genGetReturn(returnType)
	if isVoidType(returnType) then
		return ""
	elseif isIntType(returnType) then
		return returnType .. " _ret = (" .. returnType .. ")lua_tointeger(L, -1);"
	elseif isFloatType(returnType) then
		return returnType .. " _ret = (" .. returnType .. ")lua_tonumber(L, -1);"
	elseif isStringType(returnType) then
		return "const char *_ret = lua_tostring(L, -1);"
	elseif isPointerReturn(returnType) then
		return returnType .. " _ret = (" .. returnType .. ")(uintptr_t)lua_touserdata(L, -1);"
	else
		return returnType .. " _ret = (" .. returnType .. ")(uintptr_t)lua_touserdata(L, -1);"
	end
end

---Generate the C code for a single lazy-init exported function wrapper.
---@param exp lde.Export
---@return string funcDef
local function generateCExportWrapper(exp)
	local name = exp.name
	local retType = exp.returnType
	local params = exp.params

	-- Build type strings
	local paramTypes = {}
	local paramNames = {}
	for _, p in ipairs(params) do
		paramTypes[#paramTypes + 1] = p.type
		paramNames[#paramNames + 1] = p.name
	end
	local paramTypeStr = table.concat(paramTypes, ", ")
	local paramNameStr = table.concat(paramNames, ", ")

	-- Typedef for function pointer
	local typedef = "typedef " .. retType .. " (*" .. name .. "_func)(" .. paramTypeStr .. ");"

	-- Cached function pointer initialized to the init function
	local initName = name .. "_ldein"

	-- Init function body: gets the function pointer from Lua, caches it, and calls through
	local initBody = {}
	initBody[#initBody + 1] = "    lua_State *L = lde_get_state();"
	initBody[#initBody + 1] = '    lua_getglobal(L, "C_EXPORTS_' .. name .. '");'
	initBody[#initBody + 1] = "    if (lua_isnil(L, -1)) {"
	initBody[#initBody + 1] = '        luaL_error(L, "lde-shared: export not found: ' .. name .. '");'
	initBody[#initBody + 1] = "    }"
	initBody[#initBody + 1] = "    cached_" .. name .. " = (" .. name .. "_func)lua_topointer(L, -1);"
	initBody[#initBody + 1] = "    lua_pop(L, 1);"
	-- Push args
	for _, p in ipairs(params) do
		local push = genPushArg(p.type, p.name)
		if push:match("^/") then
			initBody[#initBody + 1] = "    " .. push
		elseif push ~= "" then
			initBody[#initBody + 1] = "    " .. push
		end
	end
	-- Call through cached pointer
	local nret = isVoidType(retType) and "0" or "1"
	initBody[#initBody + 1] = "    if (lua_pcall(L, " .. #params .. ", " .. nret .. ", 0) != LUA_OK) {"
	initBody[#initBody + 1] = '        const char *err = lua_tostring(L, -1);'
	initBody[#initBody + 1] = '        luaL_error(L, "lde-shared: call to ' ..
		name .. ' failed: %s", err ? err : "unknown");'
	initBody[#initBody + 1] = "    }"
	-- Get return
	local retExpr = genGetReturn(retType)
	if retExpr ~= "" then
		initBody[#initBody + 1] = "    " .. retExpr
		initBody[#initBody + 1] = "    lua_pop(L, 1);"
		initBody[#initBody + 1] = "    return _ret;"
	end

	-- The exported function: just calls through cached pointer
	local callArgs = {}
	for _, p in ipairs(params) do
		callArgs[#callArgs + 1] = p.name
	end
	local callExpr
	if isVoidType(retType) then
		callExpr = "    cached_" .. name .. "(" .. table.concat(callArgs, ", ") .. ");"
	else
		callExpr = "    return cached_" .. name .. "(" .. table.concat(callArgs, ", ") .. ");"
	end

	-- Assemble the full code
	local parts = {}
	parts[#parts + 1] = typedef
	parts[#parts + 1] = "static " .. name .. "_func cached_" .. name .. " = &" .. initName .. ";"
	parts[#parts + 1] = "static " .. retType .. " " .. initName .. "(" .. paramNameStr .. ") {"
	for _, line in ipairs(initBody) do
		parts[#parts + 1] = line
	end
	parts[#parts + 1] = "}"
	parts[#parts + 1] = "EXPORT " .. retType .. " " .. name .. "(" .. paramNameStr .. ") {"
	parts[#parts + 1] = callExpr
	parts[#parts + 1] = "}"

	return table.concat(parts, "\n")
end

---Generate the complete C source for a shared library.
---@param exports lde.Export[]
---@param source string # bundled Lua source (already escaped)
---@param libDecls string # C variable declarations for embedded shared libs
---@param libStartup string # C code to extract bundled shared libs (placed inside lde_init_lua)
---@param sharedLibPreloads string # C code that preloads shared libs via lua API (placed in lde_init_lua)
---@param loadlibHelper string # C helper function lde_loadlib_loader (file scope)
---@param ffiShim string # Lua ffi.load shim code (if any)
---@param tmpnameShim string # os.tmpname shim Lua code
---@return string cCode
local function generateSharedLibraryC(exports, source, libDecls, libStartup, sharedLibPreloads, loadlibHelper, ffiShim,
									  tmpnameShim)
	-- Combine Lua source with prelude
	local combinedSource = tmpnameShim .. "\n" .. ffiShim .. "\n" .. source

	-- Escape for C string
	local sourceEscaped = combinedSource:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub(
		"\t", "\\t")

	-- Generate wrappers for each export
	local wrapperFuncs = {}
	for _, exp in ipairs(exports) do
		wrapperFuncs[#wrapperFuncs + 1] = generateCExportWrapper(exp)
	end

	local code = [[
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lauxlib.h"
#include "lualib.h"

]] .. (libStartup:match("%S") and "#include <stdint.h>\n" or "") .. [[

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

]] .. libDecls .. [[

]] .. loadlibHelper .. [[

static lua_State* L = NULL;
static int lde_initialized = 0;

static lua_State* lde_get_state(void) {
	return L;
}

static int lde_init_lua(void) {
	if (lde_initialized) return 0;
	lde_initialized = 1;

]] .. libStartup .. [[

	L = luaL_newstate();
	if (!L) { fprintf(stderr, "lde-shared: failed to create lua_State\n"); return 1; }
	luaL_openlibs(L);

	/* Load and run the bundled Lua code */
	{
		const char* code = "]] .. sourceEscaped .. [[";
		if (luaL_loadstring(L, code) != LUA_OK) {
			fprintf(stderr, "lde-shared: failed to load bundled code: %s\n", lua_tostring(L, -1));
			lua_close(L);
			L = NULL;
			return 1;
		}

		if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
			fprintf(stderr, "lde-shared: failed to run bundled code: %s\n", lua_tostring(L, -1));
			lua_close(L);
			L = NULL;
			return 1;
		}
	}

]] .. sharedLibPreloads .. [[

	return 0;
}

]] .. table.concat(wrapperFuncs, "\n\n") .. [[

#ifdef _WIN32
#include <windows.h>
BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpReserved) {
	if (fdwReason == DLL_PROCESS_ATTACH) {
		return lde_init_lua() == 0;
	}
	return TRUE;
}
#else
__attribute__((constructor))
static void lde_shared_init(void) {
	if (lde_init_lua() != 0) {
		fprintf(stderr, "lde-shared: initialization failed\n");
	}
}
#endif
]]

	return code
end

Export.parseExportLine = parseExportLine
Export.generateCExportWrapper = generateCExportWrapper
Export.generateSharedLibraryC = generateSharedLibraryC
Export.processSourceWithExports = processSourceWithExports
Export.isIntType = isIntType
Export.isFloatType = isFloatType
Export.isStringType = isStringType
Export.isVoidType = isVoidType
Export.isPointerReturn = isPointerReturn
Export.CTypeMap = CTypeMap

return Export
