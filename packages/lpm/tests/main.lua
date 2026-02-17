local test = require("lpm-test")

test.it("should do the thing", function()
	test.equal(2, 2)
end)

test.it("should hwatever", function()
	test.notEqual(1, 2)
end)
