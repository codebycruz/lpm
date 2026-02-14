local path = require("path")
local fs = require("fs")
local util = require("util")

local Package = require("lpm-core.package")

--- Initializes a package at the given directory.
--- If the directory already contains an lpm.json, this will throw an error to avoid overwriting existing packages.
---@param dir string
local function initPackage(dir)
	local configPath = path.join(dir, "lpm.json")
	if fs.exists(configPath) then
		error("Directory already contains lpm.json: " .. dir)
	end

	fs.write(configPath, util.dedent([[
		{
			"name": "]] .. path.basename(dir) .. [[",
			"version": "0.1.0"
		}
	]]))

	local package = Package.open(dir)
	if not package then
		error("Failed to initialize package at directory: " .. dir)
	end

	local src = package:getSrcDir()
	if not fs.exists(src) then
		fs.mkdir(src)
		fs.write(path.join(src, "init.lua"), "print('Hello, world!')")
	end

	return package
end

return initPackage
