---@class env.raw
---@field var fun(name: string): string?
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

return env
