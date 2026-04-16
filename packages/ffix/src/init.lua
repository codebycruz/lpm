local ffi = require("ffi")

local ffix = {}

local Tokenizer = require("ffix.tokenizer")
local Parser = require("ffix.parser")

---@class ffix.Context
---@field private pfx string
local Context = {}
Context.__index = Context

---@param pfx string
function Context.new(pfx)
	local ctx = setmetatable({}, Context)
	ctx.pfx = pfx or string.format("%f_%p", os.clock(), ctx)
	return ctx
end

ffix.context = Context.new

---@param code string
function Context:cdef(code)
end

---@param lib string
function Context:load(lib)
	return ffi.load(lib)
end

return ffix
