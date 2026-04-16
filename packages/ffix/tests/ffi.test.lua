local test = require("lde-test")
local ffi = require("ffi")
local ffix = require("ffix")

-- each test gets a unique prefix so cdef doesn't see duplicate type names across runs
local n = 0
local function ctx()
	n = n + 1
	return ffix.context("t" .. n)
end

-- sizeof

test.it("sizeof resolves prefixed struct", function()
	local c = ctx()
	c:cdef("typedef struct { int x; int y; } Point;")
	test.equal(c:sizeof("Point"), ffi.sizeof("int") * 2)
end)

test.it("sizeof resolves prefixed alias", function()
	local c = ctx()
	c:cdef("typedef int MyInt;")
	test.equal(c:sizeof("MyInt"), ffi.sizeof("int"))
end)

-- typeof

test.it("typeof returns the right ctype", function()
	local c = ctx()
	c:cdef("typedef struct { float x; float y; float z; } Vec3;")
	local ct = c:typeof("Vec3")
	test.equal(ffi.sizeof(ct), ffi.sizeof("float") * 3)
end)

-- new

test.it("new creates a zero-initialised struct", function()
	local c = ctx()
	c:cdef("typedef struct { int a; int b; } Pair;")
	local p = c:new("Pair")
	test.equal(p.a, 0)
	test.equal(p.b, 0)
end)

test.it("new with initialiser sets fields", function()
	local c = ctx()
	c:cdef("typedef struct { int x; int y; } Coord;")
	local p = c:new("Coord", { x = 3, y = 7 })
	test.equal(p.x, 3)
	test.equal(p.y, 7)
end)

test.it("new field writes survive a read back", function()
	local c = ctx()
	c:cdef("typedef struct { int val; } Box;")
	local b = c:new("Box")
	b.val = 99
	test.equal(b.val, 99)
end)

-- cast

test.it("cast with bare type name works", function()
	local c = ctx()
	c:cdef("typedef struct { int n; } Wrap;")
	local w = c:new("Wrap", { n = 42 })
	local p = c:cast("Wrap *", w)
	test.equal(p.n, 42)
end)

test.it("cast pointer write is visible through original", function()
	local c = ctx()
	c:cdef("typedef struct { int n; } Cell;")
	local cell = c:new("Cell", { n = 1 })
	local ptr = c:cast("Cell *", cell)
	ptr.n = 55
	test.equal(cell.n, 55)
end)

-- function resolution via __asm__

test.it("declared function resolves to the real symbol via asm", function()
	local c = ctx()
	c:cdef("unsigned long strlen(const char * s);")
	-- rewriter emits: unsigned long tN_strlen(const char *s) __asm__("strlen");
	local pfx_strlen = ffi.C[c.names["strlen"]]
	test.equal(tonumber(pfx_strlen("hello")), 5)
	test.equal(tonumber(pfx_strlen("")), 0)
end)

test.it("multiple functions resolve independently", function()
	local c = ctx()
	c:cdef([[
		unsigned long strlen(const char * s);
		int atoi(const char * s);
	]])
	test.equal(tonumber(ffi.C[c.names["strlen"]]("abc")), 3)
	test.equal(tonumber(ffi.C[c.names["atoi"]]("123")), 123)
end)
