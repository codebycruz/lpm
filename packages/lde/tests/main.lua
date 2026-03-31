local test = require("lde-test")

local process = require("process")
local fs = require("fs")
local env = require("env")
local path = require("path")
local json = require("json")

local ldePath = assert(env.execPath())

---@param cmd string
local function lde(cmd)
	return process.exec(ldePath, { cmd }, { unsafe = true })
end

test.it("should do that", function()
	local ok, out = lde "--version"
end)
