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

---@param path string
---@param chunkSize number
---@param maxChunks number
---@return string?
local function readChunked(path, chunkSize, maxChunks)
	local handle = io.open(path, "rb")
	if not handle then
		return
	end

	local buf = {}
	while true do
		local chunk = handle:read(chunkSize)
		if not chunk or #buf > maxChunks then break end
		buf[#buf + 1] = chunk
	end

	handle:close()
	return table.concat(buf)
end

---@param name string
---@param args string[]?
---@param options process.CommandOptions?
---@param isStdoutEnabled boolean
local function executeCommand(name, args, options, isStdoutEnabled)
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

	local tmpOutputFile = nil
	if isStdoutEnabled then
		tmpOutputFile = os.tmpname()
		command = command .. " > " .. escape(tmpOutputFile)
	end

	local exitCode = os.execute(command)
	local ranSuccessfully = exitCode == 0

	local catastrophicFailure = nil ---@type string?
	local output ---@type string?
	if ranSuccessfully and tmpOutputFile then
		output = readChunked(tmpOutputFile, 4096, 10)
		if not output then
			catastrophicFailure = "Failed to read stdout"
		end
	elseif not ranSuccessfully then
		output = readChunked(tmpErrorFile, 4096, 10)
		if not output then
			catastrophicFailure = "Failed to read stderr"
		end
	end

	if tmpInputFile then os.remove(tmpInputFile) end
	if tmpOutputFile then os.remove(tmpOutputFile) end
	os.remove(tmpErrorFile)

	if catastrophicFailure then
		error(catastrophicFailure)
	end

	return ranSuccessfully, output
end

---@param name string
---@param args string[]?
---@param options process.CommandOptions?
---@return boolean? # Success
---@return string # Output or Fail
function process.exec(name, args, options)
	return executeCommand(name, args, options, true)
end

---@param name string
---@param args string[]?
---@param options process.CommandOptions?
---@return boolean # Success
---@return string # Fail
function process.spawn(name, args, options)
	return executeCommand(name, args, options, false)
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
