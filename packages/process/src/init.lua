local process = {}

local path = require("path")

local isWindows = path.separator == "\\"

---@param arg string
local function escape(arg)
	if isWindows then
		return '"' .. string.gsub(arg, '"', '\\"') .. '"'
	else
		return "'" .. string.gsub(arg, "'", "'\\''") .. "'"
	end
end

---@class process.CommandOptions
---@field cwd string?
---@field env table<string, string>?

---@class process.ExecOptions: process.CommandOptions
---@field stdin string?

---@class process.SpawnOptions: process.CommandOptions

---@param name string
---@param args string[]?
---@param options process.CommandOptions?
local function formatCommand(name, args, options)
	local command
	if args then
		local parts = { escape(name) }
		for i, arg in ipairs(args) do
			parts[i + 1] = escape(arg)
		end

		command = table.concat(parts, " ")
	else
		command = escape(name)
	end

	if options and options.cwd then
		command = "cd " .. escape(options.cwd) .. " && " .. command
	end

	if options and options.env then
		local parts = {}
		for k, v in pairs(options.env) do
			if isWindows then
				parts[#parts + 1] = "set " .. k:match("^[%w_]+$") .. "=" .. escape(v) .. "&&"
			else
				parts[#parts + 1] = "export " .. k:match("^[%w_]+$") .. "=" .. escape(v) .. ";"
			end
		end

		command = table.concat(parts, " ") .. " " .. command
	end

	return command
end

---@param name string
---@param args string[]
---@param options process.ExecOptions?
---@return boolean? # Success
---@return string # Output
function process.exec(name, args, options)
	local command = formatCommand(name, args, options)
	command = command .. " 2>&1" -- Redirect stderr to stdout

	local tmpfile = nil
	if options and options.stdin then
		tmpfile = os.tmpname()
		local f = io.open(tmpfile, "w")
		if f then
			f:write(options.stdin)
			f:close()
			command = command .. " < " .. escape(tmpfile)
		end
	end

	local handle = io.popen(command, "r")
	if not handle then
		error("Failed to start process: " .. command)
	end

	local output = handle:read("*a")
	local success = handle:close()

	if tmpfile then
		os.remove(tmpfile)
	end

	return success, output
end

---@param name string
---@param args string[]
---@param options process.SpawnOptions?
function process.spawn(name, args, options)
	local command = formatCommand(name, args, options)
	return os.execute(command)
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
