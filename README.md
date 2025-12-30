# lpm

`lpm` is a simple and lightweight package manager for Lua, written in Lua.

It was created due to my frustration with the current status quo of package management in the Lua ecosystem.

- [LuaRocks](https://luarocks.org) is sorely dated, difficult to manage, and hardly maintained.
- [Lux](https://github.com/lumen-oss/lux), while promising, is written in Rust and seems to be targeting backwards compatibility with LuaRocks.

## Features

- Local package installation via `lpm add --path <package>` and `lpm install` mirroring the DX of modern package managers like npm.
- `lpm bundle` - Create a single executable application from your entire project, easily distributable.

## Support

Currently, `lpm` is Lua version agnostic. But it is written with LuaJIT in mind, so there may be some incompatibilities with PUC Lua. Feel free to report any issues you find.
