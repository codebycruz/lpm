local test = require("lde-test")
local json = require("json")

-- encode

test.it("encodes primitives", function()
	test.equal(json.encode(nil):gsub("%s", ""), "null")
	test.equal(json.encode(true):gsub("%s", ""), "true")
	test.equal(json.encode(42):gsub("%s", ""), "42")
	test.equal(json.encode("hi"):gsub("%s", ""), '"hi"')
end)

test.it("encodes array", function()
	local s = json.encode({ 1, 2, 3 })
	local t = json.decode(s)
	test.equal(t[1], 1)
	test.equal(t[2], 2)
	test.equal(t[3], 3)
end)

test.it("encodes object", function()
	local s = json.encode({ a = 1 })
	local t = json.decode(s)
	test.equal(t.a, 1)
end)

-- decode – standard JSON

test.it("decodes null", function()
	test.equal(tostring(json.decode("null")), "null")
end)

test.it("decodes booleans", function()
	test.equal(json.decode("true"), true)
	test.equal(json.decode("false"), false)
end)

test.it("decodes numbers", function()
	test.equal(json.decode("42"), 42)
	test.equal(json.decode("-3.14"), -3.14)
	test.equal(json.decode("1e2"), 100)
end)

test.it("decodes strings", function()
	test.equal(json.decode('"hello"'), "hello")
	test.equal(json.decode('"line\\nbreak"'), "line\nbreak")
end)

test.it("decodes nested objects and arrays", function()
	local t = json.decode('{"a":[1,2],"b":{"c":true}}')
	test.equal(t.a[1], 1)
	test.equal(t.a[2], 2)
	test.equal(t.b.c, true)
end)

-- decode – JSON5

test.it("json5: single-line comment", function()
	local t = json.decode('{\n// comment\n"a":1}')
	test.equal(t.a, 1)
end)

test.it("json5: block comment", function()
	local t = json.decode('{"a": /* comment */ 1}')
	test.equal(t.a, 1)
end)

test.it("json5: single-quoted string value", function()
	test.equal(json.decode("'hello'"), "hello")
end)

test.it("json5: single-quoted string key", function()
	local t = json.decode("{'key': 1}")
	test.equal(t.key, 1)
end)

test.it("json5: unquoted key", function()
	local t = json.decode("{foo: 1}")
	test.equal(t.foo, 1)
end)

test.it("json5: trailing comma in object", function()
	local t = json.decode('{"a":1,}')
	test.equal(t.a, 1)
end)

test.it("json5: trailing comma in array", function()
	local t = json.decode('[1,2,3,]')
	test.equal(#t, 3)
end)

test.it("json5: hex number", function()
	test.equal(json.decode("0xFF"), 255)
end)

test.it("json5: Infinity", function()
	test.equal(json.decode("Infinity"), math.huge)
	test.equal(json.decode("+Infinity"), math.huge)
	test.equal(json.decode("-Infinity"), -math.huge)
end)

test.it("json5: NaN", function()
	local n = json.decode("NaN")
	test.truthy(n ~= n)
end)

-- order preservation

test.it("addField preserves insertion order on encode", function()
	local t = {}
	json.addField(t, "z", 1)
	json.addField(t, "a", 2)
	json.addField(t, "m", 3)
	local s = json.encode(t)
	local zi = s:find('"z"')
	local ai = s:find('"a"')
	local mi = s:find('"m"')
	test.truthy(zi < ai and ai < mi)
end)

test.it("decode preserves key insertion order", function()
	local t = json.decode('{"z":1,"a":2,"m":3}')
	local s = json.encode(t)
	local zi = s:find('"z"')
	local ai = s:find('"a"')
	local mi = s:find('"m"')
	test.truthy(zi < ai and ai < mi)
end)

test.it("removeField removes key and preserves order of remaining keys", function()
	local t = {}
	json.addField(t, "a", 1)
	json.addField(t, "b", 2)
	json.addField(t, "c", 3)
	json.removeField(t, "b")
	local s = json.encode(t)
	test.truthy(not s:find('"b"'))
	test.truthy(s:find('"a"') < s:find('"c"'))
end)

-- comment preservation

test.it("preserves single-line comment before key on re-encode", function()
	local src = '{\n// my comment\n"a": 1}'
	local t = json.decode(src)
	local out = json.encode(t)
	test.truthy(out:find("// my comment"))
end)

test.it("preserves block comment before key on re-encode", function()
	local src = '{"a": /* inline */ 1}'
	local t = json.decode(src)
	local out = json.encode(t)
	test.truthy(out:find("/%* inline %*/"))
end)

test.it("preserves trailing comment after value on re-encode", function()
	local src = '{"a": 1 // end\n}'
	local t = json.decode(src)
	local out = json.encode(t)
	test.truthy(out:find("// end"))
end)

test.it("preserves comments in array on re-encode", function()
	local src = '[/* first */ 1, /* second */ 2]'
	local t = json.decode(src)
	local out = json.encode(t)
	test.truthy(out:find("/%* first %*/"))
	test.truthy(out:find("/%* second %*/"))
end)

-- key style preservation

test.it("preserves unquoted key style on re-encode", function()
	local src = '{foo: 1}'
	local t = json.decode(src)
	local out = json.encode(t)
	-- should appear as bare identifier, not "foo"
	test.truthy(out:find("foo:") and not out:find('"foo"'))
end)

test.it("preserves single-quoted key style on re-encode", function()
	local src = "{'bar': 2}"
	local t = json.decode(src)
	local out = json.encode(t)
	test.truthy(out:find("'bar'"))
end)

test.it("preserves double-quoted key style on re-encode", function()
	local src = '{"baz": 3}'
	local t = json.decode(src)
	local out = json.encode(t)
	test.truthy(out:find('"baz"'))
end)

-- value style preservation

test.it("preserves single-quoted string value on re-encode", function()
	local src = "{key: 'hello'}"
	local t = json.decode(src)
	local out = json.encode(t)
	test.truthy(out:find("'hello'"))
end)

test.it("preserves double-quoted string value on re-encode", function()
	local src = '{"key": "world"}'
	local t = json.decode(src)
	local out = json.encode(t)
	test.truthy(out:find('"world"'))
end)

-- trailing comma preservation

test.it("preserves trailing comma in object on re-encode", function()
	local src = '{foo: 1,}'
	local t = json.decode(src)
	local out = json.encode(t)
	test.truthy(out:match("1,"))
end)

test.it("preserves trailing comma in array on re-encode", function()
	local src = '[1, 2,]'
	local t = json.decode(src)
	local out = json.encode(t)
	test.truthy(out:match("2,"))
end)