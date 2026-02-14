local fs = require("fs")
local path = require("path")

---@param package lpm.Package
---@param destinationPath string?
local function buildPackage(package, destinationPath)
	destinationPath = destinationPath or path.join(package:getModulesDir(), package:getName())

	local buildScriptPath = package:getBuildScriptPath()
	if fs.exists(buildScriptPath) then
		fs.copy(package:getSrcDir(), destinationPath)

		local ok, err = package:runScript(buildScriptPath, nil, { LPM_OUTPUT_DIR = destinationPath })
		if not ok then
			error("Build script failed for package '" .. package:getName() .. "': " .. err)
		end
	else
		fs.mklink(package:getSrcDir(), destinationPath)
	end
end

return buildPackage
