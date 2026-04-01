---
title: Requirements
order: 1
---

# Requirements

Both `lde bundle` and `lde compile` produce output tied to the LDE runtime, which is built on LuaJIT. The output is not intended to be used with standard Lua or other runtimes.

## Bundling

`lde bundle` works out of the box with no extra dependencies. The resulting `.lua` file runs under the LDE runtime (`lde run`) or any LuaJIT build.

The `--bytecode` flag compiles modules to LuaJIT bytecode. The output is only compatible with the same LuaJIT version LDE uses — it will not run on Lua 5.x or a different LuaJIT build.

## Compiling

`lde compile` requires a C compiler on the machine doing the compiling. At the moment, `gcc` is expected to be available on your `PATH`.

```sh
# Check gcc is available
gcc --version
```

To use a different compiler, set the `SEA_CC` environment variable:

```sh
SEA_CC=clang lde compile
```

The resulting binary is fully self-contained and requires no Lua or LDE installation to run.
