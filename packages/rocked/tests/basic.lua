local test = require("lpm-test")
local rocked = require("rocked")
local http = require("http")

test.it("should do this", function()
	local bustedRockspec, err = http.get(
		"https://raw.githubusercontent.com/lunarmodules/busted/56e6d68204d1456afa77f1346bf4e050df65b629/rockspecs/busted-2.3.0-1.rockspec")

	if not bustedRockspec then
		error("Failed to GET busted rockspec: " .. err)
	end

	local ok, parsed =
end)
