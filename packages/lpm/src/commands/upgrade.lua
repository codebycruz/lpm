local http = require("http")
local process = require("process")
local semver = require("semver")
local json = require("json")
local ansi = require("ansi")
local path = require("path")
local fs = require("fs")

local global = require("lpm.global")

local apiUrl = "https://api.github.com/repos/codebycruz/lpm/releases/latest"

local function getBinaryInstallLocation()
	if process.platform == "win32" then
		return path.join(global.getDir(), "lpm.exe")
	elseif process.platform == "linux" then
		return path.join(global.getDir(), "lpm")
	elseif process.platform == "darwin" then
		return path.join(global.getDir(), "lpm")
	end
end

local artifactNames = {
	win32 = "lpm-windows-x86-64.exe",
	linux = "lpm-linux-x86-64",
	darwin = "lpm-macos-x86-64",
}

---@param args clap.Args
local function upgrade(args)
	local out, err = http.get(apiUrl)
	if not out then
		ansi.printf("{red}Failed to fetch latest release: %s", err)
		return
	end

	local releaseInfo = json.decode(out)
	if not releaseInfo or not releaseInfo.tag_name or not releaseInfo.assets then
		ansi.printf("{red}Invalid release information received")
		return
	end

	local latestVersion = string.match(releaseInfo.tag_name, "v?(%d+%.%d+%.%d+)")
	if not latestVersion then
		ansi.printf("{red}Invalid version format in release tag")
		return
	end

	local runningVersion = global.currentVersion
	if semver.compare(latestVersion, runningVersion) <= 0 then
		ansi.printf("{green}You are already running the latest version (%s)", runningVersion)
		return
	end

	local binLocation = getBinaryInstallLocation()
	if not binLocation then
		ansi.printf("{red}Unsupported platform: %s", process.platform)
		return
	end

	if not fs.exists(binLocation) then
		ansi.printf("{red}Cannot upgrade: binary not found at %s", binLocation)
		return
	end

	local artifactName = artifactNames[process.platform]
	if not artifactName then
		ansi.printf("{red}No artifact available for platform: %s", process.platform)
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
		ansi.printf("{red}Could not find download URL for artifact: %s", artifactName)
		return
	end

	print("Downloading " .. artifactName .. " from " .. downloadUrl)
	local binaryData, downloadErr = http.get(downloadUrl)
	if not binaryData then
		ansi.printf("{red}Failed to download binary: %s", downloadErr)
		return
	end

	local tempLocation = binLocation .. ".tmp"
	local writeSuccess, writeErr = fs.write(tempLocation, binaryData)
	if not writeSuccess then
		ansi.printf("{red}Failed to write temporary file: %s", writeErr)
		return
	end

	if process.platform == "linux" then
		local chmodSuccess, chmodErr = process.spawn("chmod", { "+x", tempLocation })
		if not chmodSuccess then
			ansi.printf("{red}Failed to make binary executable: %s", chmodErr)
			return
		end
	end

	local moveSuccess, moveErr = fs.move(tempLocation, binLocation)
	if not moveSuccess then
		fs.delete(tempLocation)
		ansi.printf("{red}Failed to replace binary: %s", moveErr)
		return
	end

	ansi.printf("{green}Successfully upgraded to version %s!", latestVersion)
end

return upgrade
