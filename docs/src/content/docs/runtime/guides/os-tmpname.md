---
title: os.tmpname()
order: 3
---

# os.tmpname()

LDE's LuaJIT fork includes a built-in cross-platform fix for `os.tmpname()`, so no runtime override is needed.

This ensures `os.tmpname()` works correctly on Termux/Android and other platforms where the default implementation may return non-existent paths.
