---
title: Compiling to an Executable
order: 2
---

# Compiling to an Executable

`lde compile` produces a standalone native executable that bundles your Lua code, all dependencies, and the LuaJIT runtime into a single binary. Users need no Lua installation to run it.

## How it works

lde builds and installs your dependencies, then walks `./target/` collecting every `.lua` file and every native shared library (`.so` / `.dll` / `.dylib`). Lua files are embedded as preloaded modules. Native libraries are packed into the binary and extracted to a temporary directory at runtime, then resolved via `package.preload`. The binary includes the LDE runtime (LuaJIT) and is not compatible with standard Lua. See [Requirements](/docs/bundler/getting-started/requirements) for compiler prerequisites.

## Basic usage

```sh
lde compile
```

Outputs `<name>` (or `<name>.exe` on Windows) in your project root.

## Custom output path

```sh
lde compile --outfile dist/myapp
```

On Windows `.exe` is appended automatically if not already present.

## Shared library output

Pass `--shared` to compile your project as a shared library (`.so` / `.dll` / `.dylib`) instead of an executable:

```sh
lde compile --shared
```

This produces a library that initializes LuaJIT on load (via `__attribute__((constructor))` / `DllMain`). You can export C-callable functions from your Lua code using `---@export` annotations.

### Exporting functions

Add `---@export` annotations in your entrypoint file to expose Lua functions as C symbols:

```lua
---@export add fun(a: uint32_t, b: uint32_t): uint32_t
local function add(a, b)
    return a + b
end
```

The annotation format is:

```
---@export [name] fun(param: type, ...): returnType
```

- **name** (optional): The C symbol name. If omitted, the function name is used.
- **param:type**: Parameter name and C type.
- **returnType**: C return type. Use `void` for no return value.

### Supported C types

Integer types: `int`, `unsigned int`, `char`, `short`, `long`, `int8_t`–`int64_t`, `uint8_t`–`uint64_t`, `size_t`, `bool`

Floating point: `float`, `double`

Strings and pointers: `const char *`, `char *`, `void *`

### How it works

At compile time, lde injects Lua code that registers each exported function as an FFI callback in `_G.C_EXPORTS_<name>`. The generated C code creates a lazy-init wrapper for each export:

1. On first call, it retrieves the callback pointer from the Lua state and caches it.
2. Subsequent calls go directly through the cached function pointer — **zero Lua overhead**.

The exported symbols can be called from C, Rust, Python ctypes, or any language with C FFI support.

### With no exports

If your entrypoint has no `---@export` annotations, the library still initializes LuaJIT on load (running any top-level code), but exposes no C symbols.

## Native modules

Shared libraries built by a `build.lua` script are automatically included in both executable and shared library output. See [C Module Support](/docs/package-manager/dependencies/c-module-support) for how to produce them.

> On Linux the binary exports LuaJIT symbols so native modules don't require a separate Lua installation. On Windows you may need to bundle a Lua shared library alongside your executable.
