local path = require("path")

---@class env.raw
---@field var fun(name: string): string?
---@field set fun(name: string, value: string?): boolean
---@field tmpdir fun(): string
---@field cwd fun(): string
---@field execPath fun(): string?

local rawenv ---@type env.raw
if jit.os == "Windows" then
	rawenv = require("env.raw.windows")
elseif jit.os == "Linux" then
	rawenv = require("env.raw.linux")
else
	error("Unsupported OS: " .. jit.os)
end

---@class env: env.raw
local env = {}

for k, v in pairs(rawenv) do
	env[k] = v
end

local tmpCounter = 0

--- Returns a unique temporary file path.
--- Safe replacement for os.tmpname() which can segfault in compiled LuaJIT on Windows.
function env.tmpfile()
	tmpCounter = tmpCounter + 1
	return path.join(env.tmpdir(), string.format("lpm_%d_%d.tmp", os.clock() * 1000, tmpCounter))
end

return env
