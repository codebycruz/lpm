local function cb()
	local fs = require("fs")
	local path = require("path")

	it("should match glob pattern", function()
		assert.is_truthy(string.match("foo/whatever.lua", fs.globToPattern("**.lua")))
	end)

	it("should calculate relative path", function()
		local base = "/home/user/project"
		local relative = "/home/user/project/file.lua"
		assert.is_equal("file.lua", path.relative(base, relative))
	end)
end

local busted = require("busted.core")()
require("busted")(busted)
busted.wrap(cb)
cb()

local fails, errors = 0, 0
busted.subscribe({ 'error' }, function(element, parent, message)
	errors = errors + 1
	io.stderr:write(message)
	return nil, true
end)

busted.subscribe({ 'failure' }, function(element, parent, message)
	fails = fails + 1
	io.stderr:write(message)
	return nil, true
end)

local run = require("busted.execute")(busted)
run(1, {})

if fails > 0 or errors > 0 then
	os.exit(1)
end
