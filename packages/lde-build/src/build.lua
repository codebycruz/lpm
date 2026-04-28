local curl = require("curl-sys")
local fs = require("fs")
local path = require("path")

---@class lde.build.Instance
---@field outDir string
local Instance = {}
Instance.__index = Instance

---@param outDir string
---@return lde.build.Instance
function Instance.new(outDir)
	return setmetatable({ outDir = outDir }, Instance)
end

---@return string
function Instance:fetch(url)
	local res, err = curl.get(url)
	assert(res, "failed to fetch " .. url .. ": " .. err)
	return res.body
end

---@param rel string # Relative path at output dir
---@param content string
function Instance:write(rel, content)
	local full = path.join(self.outDir, rel)
	fs.mkdirAll(path.dirname(full))
	assert(fs.write(full, content), "failed to write " .. full)
end

---@param rel string # Relative path at output dir
---@return string
function Instance:read(rel)
	local full = path.join(self.outDir, rel)
	local res = fs.read(full)
	assert(res, "failed to read " .. full)
	return res
end

---@param cmd string
function Instance:sh(cmd)
	local res = os.execute(cmd)
	assert(res == 0, "failed to execute " .. cmd)
end

return Instance
