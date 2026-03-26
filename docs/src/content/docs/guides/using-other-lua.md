---
title: Alternate Lua Engines
order: 3
---

# Using an Alternate Lua Engine

By default, LPM ships with the [LPM Runtime](/docs/features/runtime) which is based on LuaJIT.

But LPM supports usage of other Lua Engines, such as Lua 5.4

To do this, edit your `lpm.json` to provide which program to run instead of using LPM.

```json
{
	"name": "myproject",
	"engine": "lua5.4"
}
```

After this, `lpm run` will try to use that engine you provided.

_This currently does NOT support running tests, which are integrated with the LPM runtime!_
