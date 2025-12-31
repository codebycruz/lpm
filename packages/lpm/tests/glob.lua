local fs = require("fs")
local path = require("path")

assert(string.match("foo/whatever.lua", fs.globToPattern("**.lua")))

local base = "/home/user/project"
local relative = "/home/user/project/file.lua"

assert(path.relative(base, relative) == "file.lua")
