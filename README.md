# lpm

`lpm` is a package manager for Lua, written in Lua.

It was created due to my frustration with the current status quo of package management in the Lua ecosystem.

- [LuaRocks](https://luarocks.org) is sorely dated, difficult to manage, and hardly maintained.
- [Lux](https://github.com/lumen-oss/lux), while promising, is written in Rust and seems to be targeting backwards compatibility with LuaRocks.

## Features

- Local package management, no venv or global installs.
- Relative package installation via `lpm add --path <package>` and `lpm install`.
- Git repository installation via `lpm add --git <repo>` supporting monorepos/subdirectories.
- `lpm compile` - Create a single executable application from your entire project, easily distributable.
- `lpm test` - Run test lua scripts in your project.

## Requirements

- glibc 2.35+
- `gcc` if you plan on using `lpm compile`
    - This requirement may be lifted at some point in the future.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/codebycruz/lpm/master/install.sh | sh
```

Windows

```powershell
irm https://raw.githubusercontent.com/codebycruz/lpm/master/install.ps1 | iex
```

## Quickstart

```bash
lpm new myproject
cd myproject
lpm add hood --git https://github.com/codebycruz/hood
echo "print(require('hood'))" > ./src/init.lua
lpm run
# Output: table: 0x7f53326fd030
```
