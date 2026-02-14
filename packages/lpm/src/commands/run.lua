local Package = require("lpm-core.package")

local path = require("path")

---@param args clap.Args
local function run(args)
	local pkg, err = Package.open()
	if not pkg then
		error("Failed to open package: " .. err)
	end

	pkg:build()

	pkg:installDependencies()
	if not args:flag("production") then
		pkg:installDevDependencies()
	end

	local scriptArgs = {}
	local scriptPath = nil ---@type string?

	local dash, dashPos = args:flag("")
	if dash then
		if dashPos ~= 0 then
			scriptPath = args:pop()
		end

		scriptArgs = args:drain(dashPos)
	else
		scriptPath = args:pop()
	end

	scriptPath = scriptPath or path.join(pkg:getTargetDir(), "init.lua")

	local ok, err = pkg:runScript(scriptPath, scriptArgs)
	if not ok then
		error("Failed to run script: " .. err)
	end
end

return run
