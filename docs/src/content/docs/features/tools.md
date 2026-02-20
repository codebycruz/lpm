---
title: Tools
order: 6
---

# Tools

LPM has support for running packages as tools, which is useful for command line applications, build tools, and more.

Any package is automatically a 'tool', simply by the nature of packages all having init.lua as their entrypoint.

## lpm x

You can run any package from git or a local path.

```bash
lpm x triangle --git https://github.com/codebycruz/hood
```

This clones the hood repository, resolves the triangle package, and then instantly runs the package. You can do this with --path dependencies as well.

## lpm install

But this is quite tedious if you need to repeatedly run this tool, so you can install tools to your PATH.

```bash
lpm install triangle --git https://github.com/codebycruz/hood
# Now you can run `triangle` from your terminal!
triangle
```

## lpm uninstall

To remove previously installed tools, you can run:

```bash
lpm uninstall triangle
```

## Ensuring your PATH is correct

If you have an older version of lpm or having issues with PATH not resolving the tools, try running this:

```bash
lpm --update-path
```
