# lde-test

This is the built-in test framework for the lde runtime.

It has a simple syntax and is quite minimal.

## Example

```lua
local test = require("lde-test")

test.it("should be equal", function()
    test.equal(1, 1)
end)

test.it("should be not equal", function()
    test.notEqual(1, 2)
end)
```
