---
title: Requirements
order: 1
---

# Requirements

Both `lde bundle` and `lde compile` produce output tied to the LDE runtime, which is built on LuaJIT. The output is not intended to be used with standard Lua or other runtimes.

## Bundling

`lde bundle` works out of the box with no extra dependencies. The resulting `.lua` file runs under the LDE runtime (`lde run`) or any LuaJIT build.

The `--bytecode` flag compiles modules to LuaJIT bytecode. The output is only compatible with the same LuaJIT version LDE uses. It will not run on Lua 5.x or a different LuaJIT build.

## Compiling

`lde compile` requires a C compiler:

- **Windows**: lde automatically downloads and sets up MinGW on first use. No manual setup is needed. See [Windows C Compilation](/docs/general/features/windows-mingw) for details.
- **Linux**: install `gcc` via your package manager (e.g., `apt install gcc`, `dnf install gcc`).
- **macOS**: GCC comes with Xcode Command Line Tools. Run `xcode-select --install` if not already installed.

To use a different compiler, set the `SEA_CC` environment variable:

```sh
SEA_CC=clang lde compile
```

The resulting binary is fully self-contained and requires no Lua or LDE installation to run.
