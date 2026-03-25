local ansi = require("ansi")
local env = require("env")
local path = require("path")
local ffi = require("ffi")

local lpm = require("lpm-core")

---@param _args clap.Args
local function repl(_args)
	ansi.printf("{blue}{bold}lpm repl{reset} — LuaJIT interactive shell")
	ansi.printf("{gray}Type {bold}exit(){reset}{gray} or press Ctrl+C to quit.\n")

	-- Set up package paths if inside an lpm project
	local pkg = lpm.Package.open()
	local luaPath, luaCPath = package.path, package.cpath

	if pkg then
		pkg:build()
		pkg:installDependencies()

		local modulesDir = pkg:getModulesDir()
		luaPath = path.join(modulesDir, "?.lua") .. ";"
			.. path.join(modulesDir, "?", "init.lua") .. ";"
			.. luaPath
		luaCPath = (
			ffi.os == "Linux" and path.join(modulesDir, "?.so") or
			ffi.os == "Windows" and path.join(modulesDir, "?.dll") or
			path.join(modulesDir, "?.dylib")
		) .. ";" .. luaCPath

		local config = pkg:readConfig()
		ansi.printf("{gray}Project: {green}%s {gray}(%s)", config.name or "unknown", pkg:getDir())
	end

	-- Accumulate multi-line input
	local buffer = ""
	local lineNum = 1

	local function prompt()
		if buffer ~= "" then
			io.write(ansi.format("{gray}...{reset} "))
		else
			io.write(ansi.format("{blue}>{reset} "))
		end
		io.flush()
	end

	local savedPath, savedCPath = package.path, package.cpath
	package.path = luaPath
	package.cpath = luaCPath

	-- Shared environment for the session
	local G = setmetatable({}, { __index = _G })
	G._ENV = G

	-- exit() helper
	G.exit = function(code) os.exit(code or 0) end

	local function pretty(val, indent, seen)
		indent = indent or 0
		seen = seen or {}
		local t = type(val)
		if t == "string" then
			return ansi.format("{green}\"" .. val:gsub('"', '\\"') .. "\"")
		elseif t ~= "table" then
			return ansi.format("{yellow}" .. tostring(val))
		elseif seen[val] then
			return ansi.format("{gray}<circular>")
		end
		seen[val] = true
		local pad = string.rep("  ", indent)
		local inner = string.rep("  ", indent + 1)
		local items = {}
		for k, v in pairs(val) do
			local key = type(k) == "string"
				and ansi.format("{cyan}" .. k .. "{reset}")
				or ansi.format("{magenta}[" .. tostring(k) .. "]{reset}")
			items[#items + 1] = inner .. key .. " = " .. pretty(v, indent + 1, seen)
		end
		seen[val] = nil
		if #items == 0 then return "{}" end
		return "{\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "}"
	end

	while true do
		prompt()
		local line = io.read("*l")

		if line == nil then -- EOF / Ctrl+D
			print("")
			break
		end

		if line == "exit()" or line == "quit()" then
			break
		end

		buffer = buffer == "" and line or (buffer .. "\n" .. line)

		-- Try as expression first (return <expr>)
		local chunk, err = loadstring("return " .. buffer, "repl")
		if not chunk then
			-- Try as statement
			chunk, err = loadstring(buffer, "repl")
		end

		if chunk then
			setfenv(chunk, G)
			local ok, result = pcall(chunk)
			if ok then
				if result ~= nil then
					ansi.printf("{gray}={reset} %s", pretty(result))
				end
			else
				ansi.printf("{red}%s", tostring(result))
			end
			buffer = ""
			lineNum = lineNum + 1
		elseif err and err:find("<eof>") then
			-- Incomplete input, keep buffering
		else
			ansi.printf("{red}%s", tostring(err))
			buffer = ""
		end
	end

	package.path = savedPath
	package.cpath = savedCPath
end

return repl
