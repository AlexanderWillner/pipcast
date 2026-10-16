---
title: Install
description: Install signed and notarized Pipcast releases with Homebrew or a DMG.
---

Pipcast requires macOS 26 or later, on Apple silicon or Intel.

## Homebrew

The current release is a beta:

```bash
brew install --cask mSarheed/pipcast/pipcast@beta
```

The cask selects the Apple silicon or universal download for your Mac. Beta installs as
`Pipcast Beta.app`. Stable releases will use `mSarheed/pipcast/pipcast` when available.
Each channel has separate settings and permissions; use [Backup](/docs/reference/backup)
to move your setup between them.

## Direct download

Download a DMG from [Releases](https://github.com/mSarheed/pipcast/releases) and drag the
app into Applications. Release builds are Developer ID signed and notarized by Apple.
No quarantine-removal command is needed.

## Updates

Use **Check for Updates** in the menu bar, or enable automatic update checks in Settings.
The updater follows your installed release channel and verifies the downloaded app's signing identity.
New releases are published manually. See [Updates](/docs/reference/updates).

## Uninstall

```bash
brew uninstall --cask mSarheed/pipcast/pipcast@beta
```

Uninstalling preserves your settings and data. Beta data lives under
`~/Library/Application Support/io.github.msarheed.pipcast.app.beta` and
`~/Library/Caches/io.github.msarheed.pipcast.app.beta`. API keys and extension sign-ins
are stored in your login Keychain.
