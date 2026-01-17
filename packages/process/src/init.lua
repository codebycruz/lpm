local process = {}

local path = require("path")

local isWindows = path.separator == "\\"

---@param arg string
local function escape(arg)
	if isWindows then
		if not string.match(arg, '[%s"^&|<>%%]') and arg ~= "" then
			return arg
		end

		local inner = arg
			:gsub('(\\+)"', function(backslashes)
				return backslashes .. backslashes .. '\\"'
			end)
			:gsub('(\\+)$', function(backslashes)
				return backslashes .. backslashes
			end)
			:gsub('"', '\\"')

		return '"' .. inner .. '"'
	else
		return "'" .. string.gsub(arg, "'", "'\\''") .. "'"
	end
end

---@class process.CommandOptions
---@field cwd string?
---@field env table<string, string>?
---@field unsafe boolean? # If true, do not escape command and arguments. Especially useful because windows is completely worthless :)

---@class process.ExecOptions: process.CommandOptions
---@field stdin string?

---@class process.SpawnOptions: process.CommandOptions

---@param name string
---@param args string[]?
---@param options process.CommandOptions?
local function formatCommand(name, args, options)
	local escapeFunc = (options and options.unsafe) and function(s) return s end or escape

	if process.platform ~= "win32" then
		name = escapeFunc(name)
	end

	local command
	if args then
		local parts = { name }
		for i, arg in ipairs(args) do
			parts[i + 1] = escapeFunc(arg)
		end

		command = table.concat(parts, " ")
	else
		command = name
	end

	if options and options.cwd then
		if isWindows then
			command = "cd /d " .. escapeFunc(options.cwd) .. " && " .. command
		else
			command = "cd " .. escapeFunc(options.cwd) .. " && " .. command
		end
	end

	if options and options.env then
		local parts = {}
		for k, v in pairs(options.env) do
			if isWindows then
				parts[#parts + 1] = "set " .. string.match(k, "^[%w_]+$") .. "=" .. escapeFunc(v) .. "&&"
			else
				parts[#parts + 1] = "export " .. string.match(k, "^[%w_]+$") .. "=" .. escapeFunc(v) .. ";"
			end
		end

		command = table.concat(parts, " ") .. " " .. command
	end

	return command
end

---@param name string
---@param args string[]?
---@param options process.ExecOptions?
---@return boolean? # Success
---@return string # Output
function process.exec(name, args, options)
	local command = formatCommand(name, args, options)

	local tmpErrorFile = os.tmpname()
	command = command .. " 2>" .. escape(tmpErrorFile)

	local tmpInputFile = nil
	if options and options.stdin then
		tmpInputFile = os.tmpname()
		local f = io.open(tmpInputFile, "wb")
		if f then
			f:write(options.stdin)
			f:close()
			command = command .. " < " .. escape(tmpInputFile)
		end
	end

	local handle = io.popen(command, "r")
	if not handle then
		error("Failed to start process: " .. command)
	end

	-- This can error if OOM
	local _ok, stdout = pcall(function()
		return handle:read("*a")
	end)
	local success = handle:close()

	if tmpInputFile then
		os.remove(tmpInputFile)
	end

	local output
	if success then
		output = stdout
	else
		local handle = io.open(tmpErrorFile, "rb")

		local stderr = {}
		while true do
			local chunk = handle:read(4096)
			if not chunk or #stderr > 10 then break end
			stderr[#stderr + 1] = chunk
		end

		output = table.concat(stderr)
	end

	os.remove(tmpErrorFile)

	return success, output
end

---@param name string
---@param args string[]
---@param options process.SpawnOptions?
function process.spawn(name, args, options)
	return os.execute(formatCommand(name, args, options))
end

if isWindows then
	process.platform = "win32"
else
	local ok, out = process.exec("uname", { "-s" })
	if ok then
		if string.match(out, "^Linux") then
			process.platform = "linux"
		elseif string.match(out, "^Darwin") then
			process.platform = "darwin"
		else
			process.platform = "unix"
		end
	else
		process.platform = "unix"
	end
end

return process
