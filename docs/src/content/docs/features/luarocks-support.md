---
title: Luarocks Support
order: 9
---

# Luarocks Support

LPM supports rockspecs and the [luarocks package registry](https://luarocks.org/) backwards compatibly.

## Installing a luarocks dependency

Simply prepend `rocks:` to add a luarocks dependency the same way you would an lpm dependency!

```sh
lpm add rocks:luasocket
```

## Installing a luarocks tool

Same thing here!

```sh
lpm install rocks:busted
```

## Compatibility

If you have any issues with compatibility, please do [make an issue](https://github.com/codebycruz/lpm/issues).
