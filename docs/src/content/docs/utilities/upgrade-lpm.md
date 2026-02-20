---
title: Upgrading LPM
order: 1
---

# Upgrading LPM

To upgrade lpm, simply run the following command:

```bash
lpm upgrade
```

This will check if you're on the latest version, otherwise, it will download the latest release from GitHub and replace the running binary at ~/.lpm/lpm with it.

## Forcing an upgrade

If your install is broken in some way, or you want to reinstall, you can use --force to ensure the upgrade happens regardless.

```bash
lpm upgrade --force
```

## Upgrading to a specific version

You can use the --version flag to specify a specific version to upgrade to, which is useful if you want to downgrade or upgrade to a specific pre-release.

```bash
lpm upgrade --version=0.6.0
```
