---
title: Introduction
order: 0
---

# Introduction

LPM is a package manager, runtime, test runner and bundler for Lua. It ships as a single executable with LuaJIT bundled in for you.

The days of fiddling with Lua and Luarocks setups are over. Provide users a single binary without dependencies of your project with a simple `lpm compile`!

## Getting Started

Create a new project with `lpm new ./myproject` (or `lpm init`).

```sh
lpm new myproject && cd myproject
echo "print('Hello, world!')" > ./src/init.lua
```

## Adding Dependencies

Add dependencies with a simple `lpm add` which supports git, registry and luarocks dependencies all in one!

Dependencies are resolved locally to your project for easy access to lua without polluting your PATH, or needing some kind of virtual environment.

```sh
lpm add hood --git https://github.com/codebycruz/hood
lpm add rocks:luasocket
```

## Running Your Project

LPM ships with a runtime. You can run your project's entrypoint with `lpm run`. To use an external lua engine like Lua 5.4, [see this article](/docs/guides/using-other-lua).

```sh
lpm run
# 'Hello, world!' is printed to the console
```

## Running Lua Tools

Run any remote tool easily with `lpx`!

```sh
lpx cowsay hi
```

```
 ----
< hi >
 ----
       \   ^__^
        \  (oo)\_______
           (__)\       )\/\
               ||----w |
               ||     ||
```

## Test Your Code

LPM can **test** your code with `lpm test`. LPM ships a minimal built-in test framework, required as `lpm-test`, which accompanies the default test executor which simply runs every file inside of your `tests` folder.

```lua
local test = require('lpm-test')

test.it("should add numbers", function()
	test.equal(2, 2)
end)

test.it("should not be equal", function()
	test.notEqual(2, 3)
end)
```

## Compile Your Code

LPM can **compile** your code into a single executable. Users don't need any dependencies to run your project, just run `lpm compile` and go!

## Next Steps

Head to [Installation](/docs/getting-started/installation) to get lpm on your machine, or jump straight to the [Quick Start](/docs/getting-started/quick-start) if you've already installed it.
