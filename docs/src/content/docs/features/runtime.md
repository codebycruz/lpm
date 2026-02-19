---
title: Runtime
order: 2
---

# Runtime

By default, `lpm run` uses the LPM runtime, which is based on the latest LuaJIT version that lpm itself uses to run.

This is useful so users don't need to have any version of lua installed on their system to run your project, since the LPM runtime is bundled with LPM itself automatically.

## Using an alternative engine

Currently, support for this is not as clean as it could be, but you can set the "engine" field inside of your `lpm.json` to use any CLI with the same api as the traditional PUC Rio Lua interpreter.

For example, this will make sure your project runs using the `lua5.4` binary when using `lpm run`:

```json
{
	"name": "myproject",
	"engine": "lua5.4"
}
```

_This currently does NOT support running tests, which are integrated with the LPM runtime!_

## Test runner

The LPM runtime comes with a built-in test runner, `lpm-test`, which you can read more about on its dedicated docs page: [Test Runner](/docs/features/test-runner).
