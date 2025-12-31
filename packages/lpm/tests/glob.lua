local fs = require("fs")

assert(string.match("foo/whatever.lua", fs.globToPattern("**.lua")))
