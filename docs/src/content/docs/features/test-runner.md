---
title: Test Runner
order: 3
---

# Test Runner

Testing is essential. That's why most programming languages ship their own form of testing capabilities with their runtimes.

Rust has `cargo test`, Node recently even got `node:test`, Bun has `bun test`.

So why not Lua? That's why lpm comes with a built-in test runner!

## lpm test

This command is used to run a set of lua files you create inside of your /tests/ folder. You can nest them in folders however you like.

It will run all of the files in that folder using the [LPM runtime](/docs/features/runtime).

But just running files isn't traditionally enough. Usually you write more than a single test per file.

This is why lpm ships the minimal testing library, [`lpm-test`](#`lpm-test`).

## lpm-test

This is a minimal testing library that comes bundled with lpm. You can require it in your test files and use its simple API to write tests.

```lua
local test = require("lpm-test")

test.it("should add numbers correctly", function()
	test.equal(1 + 1, 2)
end)

test.it("should handle tables", function()
	local t = {1, 2, 3}
	test.notEqual(#t, 4)
end)
```

## External Test Runners

Currently, there is no support for external test runners. In the future, it would be nice to support something like [busted](https://github.com/lunarmodules/busted) out of the box. But that raises problems with the fact we don't support luarocks packages, hence why the minimal `lpm-test` was created as the default test runner.

You can find a tracking issue for this here, give it a thumbs up if you'd like to see it happen: https://github.com/codebycruz/lpm/issues/48
