local fs = require("fs")

assert(string.match("whatever.lua", fs.globToPattern("*.lua")))
