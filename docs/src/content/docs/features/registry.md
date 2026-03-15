---
title: Registry
order: 7
---

# Registry

LPM has its own custom package registry. This means you can get packages via `lpm add <name>` and publish them with `lpm publish`.

It is hosted purely on GitHub, so no files or binaries are hosted, it just acts as a bridge to hosted git repositories, with version pinning that abides to semver.

## Adding a dependency

You can use `lpm add <name>` to add a dependency to an lpm registry package. This will resolve the latest version of the package, pin it to the git commit, and add it to your lockfile.

To add it with a specific version, you can use `lpm add <name>@<version>` or `lpm add <name> --version <version>`.

## Updating dependencies

Use `lpm update` to update registry dependencies to the latest compatible version (minor or patch updates only; major version bumps are never applied automatically).

## Publishing a package

Publishing a package is as simple as creating a pull request to the [lpm-registry](https://github.com/codebycruz/lpm-registry) repository with a single JSON file.

This is simplified with a single `lpm publish` command which automatically opens your browser to a URL with the necessary info pre-filled to make a pull request.
