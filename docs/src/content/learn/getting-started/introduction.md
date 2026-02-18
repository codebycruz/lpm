---
title: Introduction
order: 0
---

# Introduction

Lpm is a package manager and runtime for Lua, written in Lua. It ships as a single executable with LuaJIT bundled in, so there's nothing else to install.

The days of fiddling with getting both Lua and Luarocks installed are over. We extend this to users of your projects too, just run `lpm compile` to ship a binary that runs your project on any machine without Lua!

## Why lpm?

The Lua ecosystem has historically lacked a modern, ergonomic package manager.

- [LuaRocks](https://luarocks.org) is very old, lacks a lot of features you'd want out of a modern package manager, and is notoriously difficult to set up. It is 'the standard', but it has never been perfect, leading to sharding in the ecosystem with the likes of other runtimes like love2d, luvit, etc, opting to deal with dependencies on their own way.
- [Lux](https://github.com/lumen-oss/lux) is actually quite promising and was created recently, before LPM. But it is targeting backwards compatibility with luarocks, and is written in Rust. Our goals don't quite align. But I encourage you to check it out if lpm isn't a fit!

LPM takes a different approach. It's written in Lua itself (if you're using lua, you can contribute!), and was designed to create rigid standards for project structure and dependency management. It is not targeting backwards compatibility with luarocks in the forseeable future, but it is worth looking into if you're writing a mostly Lua project and have dependencies of your own.

## What can it do?

LPM can create new lua projects with `lpm new`, which will create a folder and initialize a git repo for you. Or do that in an existing directory with `lpm init`.

```sh
lpm new myproject
cd myproject
echo "print('Hello, world!')" > ./src/init.lua
```

LPM can add dependencies to your project with `lpm add`, which supports both git and local path dependencies (monorepos!). Dependencies are resolved locally to your project for easy access to lua without polluting your PATH, or needing some kind of virtual environment.

```sh
lpm add hood --git https://github.com/codebycruz/hood
```

LPM can run your project with with `lpm run`, this will by default use the lpm runtime, which is using the latest LuaJIT that comes with `lpm` itself! You can also specify an external runtime, ie simply `lua`, via the `engine` field in your `lpm.json`.

```sh
lpm run
# 'Hello, world!' is printed to the console
```

LPM can also run remote projects directly with `lpm x`. If you're familiar with Node.js, this is `npx` for Lua! Run this command to see a window rendering a triangle with OpenGL from the `hood` rendering library example!

```sh
lpm x triangle --git https://github.com/codebycruz/hood
```

LPM can **test** your code with `lpm test`. LPM ships a minimal built-in test framework, required as `lpm-test`, which accompanies the default test executor which simply runs every file inside of your `tests` folder.

Here's a little example.

```lua
local test = require('lpm-test')

test.it("should add numbers", function()
	test.equal(2, 2)
end)

test.it("should not be equal", function()
	test.notEqual(2, 3)
end)
```

LPM can **compile** your code into a single executable. No need for luastatic or any other tool, nor do users need to have lua to run your projects, just run `lpm compile`!

All of these features are just the main ones, there's much more, just ask `lpm help`!

## Project structure

An lpm project looks like this:

```
myproject/
├── lpm.json # Your main project file!
├── .luarc.json # Generated for LuaLS typings!
├── .gitignore
├── src/
│   └── init.lua # init.lua is your entrypoint!
└── tests/
    └── test.lua # Can have multiple files, name doesn't matter!
```

The `lpm.json` file defines your project:

```json
{
	"name": "myproject",
	"version": "0.1.0",
	"dependencies": {
		"hood": { "git": "https://github.com/codebycruz/hood" }
	}
}
```

There are two types of dependencies:

- **`git`** - Cloned from a git repository, with optional `branch` and `commit` pinning.
- **`path`** - Resolved from a local filesystem path, useful for monorepos and local development.

## Next steps

Head to [Installation](/learn/getting-started/installation) to get lpm on your machine, or jump straight to the [Quick Start](/learn/getting-started/quick-start) if you've already installed it.
