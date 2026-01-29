---@class lpm.test.Expect
---@field toBe fun(self: lpm.test.Expect, expected: any)
---@field toEqual fun(self: lpm.test.Expect, expected: any)

---@class lpm.test
---@field test fun(name: string, fn: fun())
---@field expect fun(value: any): lpm.test.Expect

return {} ---@as lpm.test
