local lde = require("lde-core")
local fs = require("fs")
local path = require("path")

---@param alias string
---@param depInfo lde.Package.Config.ArchiveDependency
---@return lde.Package, lde.Lockfile.ArchiveDependency
local function resolve(alias, depInfo)
	local archiveDir = lde.global.getOrInitArchive(depInfo.archive)

	-- For .src.rock archives, find the rockspec and source subdir (same as util.openLuarocksPackage)
	local pkgDir, rockspecPath = archiveDir, depInfo.rockspec
	if depInfo.archive:match("%.src%.rock$") and not depInfo.rockspec then
		local iter = fs.readdir(archiveDir)
		if iter then
			for entry in iter do
				if entry.type == "file" and entry.name:match("%.rockspec$") then
					rockspecPath = path.join(archiveDir, entry.name)
				elseif entry.type == "dir" and pkgDir == archiveDir then
					pkgDir = path.join(archiveDir, entry.name)
				end
			end
		end
	end

	local pkg, err = lde.Package.open(pkgDir, rockspecPath)
	if not pkg then
		error("Failed to load archive dependency '" .. alias .. "': " .. (err or ""))
	end
	return pkg, { archive = depInfo.archive, name = depInfo.name, rockspec = depInfo.rockspec }
end

return resolve
