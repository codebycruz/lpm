local Package = require("lpm.package")

---@param args clap.Args
local function run(args)
	local file = assert(args:pop("string"), "Usage: lpm run whatever.lua")

	local ok, err = Package.open():runScript(file)
	if not ok then
		error("Failed to run script: " .. err)
	end
end

return run
