---
title: Package Manager
order: 1
---

# Package Manager

The central feature of lpm is the package manager. It allows you to add dependencies to your project and installs them to a folder local to your project which lua's require() can resolve to.

## Adding a dependency

You can add a dependency by adding a field to your `lpm.json` file.

An example list of dependencies:

```json
"dependencies": {
	"hood": { "path": "../hood" },
	"lpm-test": { "git": "https://github.com/codebycruz/lpm" },
}
```

This can be automated with the `lpm add` command. For git dependencies, do `lpm add <name> --git <repo>` and for local dependencies, do `lpm add --path <package>`.

## Removing a dependency

Simply remove the entry from your `lpm.json`, or use `lpm remove <name>`.

## Running your program with dependencies

You can use `lpm install` to build all of your dependencies to a folder `./target/` inside of your project.

If you're just running a normal Lua project, you can simply use `lpm run` which will configure lua automatically to resolve dependencies from your /target/ directory automatically.

By default, `lpm run` will use the [LPM Runtime](/docs/features/runtime), which you can read about more on its dedicated page.
