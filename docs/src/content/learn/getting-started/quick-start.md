---
title: Quick Start
order: 3
---

# Quick Start

Get up and running with lpm in under a minute.

## Create a new project

```sh
lpm new myproject && cd myproject
```

## Add a package

For this example, we'll import the `path` library from lpm itself.

```sh
lpm add path --git https://github.com/codebycruz/lpm
```

## Write your main file

Edit `src/init.lua` to look like this:

```lua
-- You'll get LuaLS typings from this!
local path = require("path")
print(path.join("hello", "world"))
```

## Run your project

```sh
lpm run
# 'hello/world'
```

That's it. It's that simple. You just ran your project with a dependency from an entirely remote git repository stored in a monorepo, with all the heavy lifting done by lpm!
