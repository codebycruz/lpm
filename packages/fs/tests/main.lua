local fs = require("fs")
local env = require("env")
local path = require("path")

local tmp = path.join(env.tmpdir(), "fs-tests")

do
	local file = path.join(tmp, "test.txt")

	local content = "Hello, World!"
	fs.write(file, content)

	local data = fs.read(file)
	assert(data == content, "File content mismatch")
	assert(fs.isfile(file), "File is not a file")
	assert(fs.exists(file), "File does not exist")
end
