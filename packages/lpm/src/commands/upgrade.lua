local Package = require("lpm.package")

local http = require("http")
local process = require("process")
local semver = require("semver")
local json = require("json")
local ansi = require("ansi")
local path = require("path")
local fs = require("fs")

local global = require("lpm.global")

local repoUrl = "https://github.com/codebycruz/lpm"
local apiUrl = "https://api.github.com/repos/codebycruz/lpm/releases/latest"

local function getBinaryInstallLocation()
	if process.win32 then
		return path.join(global.getDir(), "lpm.exe")
	elseif process.linux then
		return path.join(global.getDir(), "lpm")
	elseif process.darwin then
		return path.join(global.getDir(), "lpm")
	end
end

local artifactNames = {
	win32 = "lpm-windows-x86_64.exe",
	linux = "lpm-linux-x86_64",
	darwin = "lpm-macos-x86_64",
}

---@param args clap.Args
local function upgrade(args)
	local out, err = http.get(apiUrl)
	if not out then
		print(ansi.colorize(ansi.red, "Failed to fetch latest release: " .. err))
		return
	end

	local releaseInfo = json.decode(out)
	if not releaseInfo or not releaseInfo.tag_name or not releaseInfo.assets then
		print(ansi.colorize(ansi.red, "Invalid release information received"))
		return
	end

	local latestVersion = string.match(releaseInfo.tag_name, "v?(%d+%.%d+%.%d+)")
	if not latestVersion then
		print(ansi.colorize(ansi.red, "Invalid version format in release tag"))
		return
	end

	local runningVersion = global.currentVersion
	if semver.compare(latestVersion, runningVersion) <= 0 then
		print(ansi.colorize(ansi.green, "You are already running the latest version (" .. runningVersion .. ")"))
		return
	end

	local binLocation = getBinaryInstallLocation()
	if not binLocation then
		print(ansi.colorize(ansi.red, "Unsupported platform: " .. process.platform))
		return
	end

	if not fs.exists(binLocation) then
		print(ansi.colorize(ansi.red, "Cannot upgrade: binary not found at " .. binLocation))
		return
	end

	local artifactName = artifactNames[process.platform]
	if not artifactName then
		print(ansi.colorize(ansi.red, "No artifact available for platform: " .. process.platform))
		return
	end

	local downloadUrl = nil
	for _, asset in ipairs(releaseInfo.assets) do
		if asset.name == artifactName then
			downloadUrl = asset.browser_download_url
			break
		end
	end

	if not downloadUrl then
		print(ansi.colorize(ansi.red, "Could not find download URL for artifact: " .. artifactName))
		return
	end

	print("Downloading " .. artifactName .. " from " .. downloadUrl)
	local binaryData, downloadErr = http.get(downloadUrl)
	if not binaryData then
		print(ansi.colorize(ansi.red, "Failed to download binary: " .. downloadErr))
		return
	end

	local tempLocation = binLocation .. ".tmp"
	local writeSuccess, writeErr = fs.write(tempLocation, binaryData)
	if not writeSuccess then
		print(ansi.colorize(ansi.red, "Failed to write temporary file: " .. writeErr))
		return
	end

	if not process.win32 then
		local chmodSuccess, chmodErr = process.spawn("chmod", { "+x", tempLocation })
		if not chmodSuccess then
			print(ansi.colorize(ansi.red, "Failed to make binary executable: " .. chmodErr))
			return
		end
	end

	local moveSuccess, moveErr = fs.rename(tempLocation, binLocation)
	if not moveSuccess then
		fs.delete(tempLocation)
		print(ansi.colorize(ansi.red, "Failed to replace binary: " .. moveErr))
		return
	end

	print(ansi.colorize(ansi.green, "Successfully upgraded to version " .. latestVersion .. "!"))
end

return upgrade
