# Pipcast

<img src="docs/branding/pipcast-logo.svg" alt="Pipcast" width="128">

A free, native macOS launcher with app search, hotkeys, clipboard history, snippets,
window management, notes, an inline calculator, and support for Raycast extensions.
Requires macOS 26 or later.

Pipcast is an independent fork of [Tinycast](https://github.com/abue-ammar/tinycast),
created by Abue Ammar and contributors. It is not an official Tinycast release.
Original copyright and third-party notices are preserved in [LICENSE](LICENSE) and
[NOTICE.md](NOTICE.md). Pipcast remains licensed under AGPL-3.0-or-later.

## Install the beta

```sh
brew install --cask mSarheed/pipcast/pipcast@beta
```

The tap chooses the Apple silicon or universal build for your Mac. Alternatively,
download the DMG from [Releases](https://github.com/mSarheed/pipcast/releases).
Release builds are Developer ID signed and notarized; no quarantine-removal command is needed.
The in-app updater follows your installed channel. Releases are published manually.

## Development

Open `Pipcast.xcodeproj`, or follow [development.md](docs/development.md).
`project.yml` is the source of truth for the XcodeGen project. Build the `Pipcast` scheme.
Debug installs as `Pipcast Dev.app`, separately from beta and stable builds.

Pipcast uses `io.github.msarheed.pipcast.app` (stable), `.app.beta` (beta), and `.app.dev`
(Debug). Settings, storage and permissions stay separate from Tinycast.
The optional settings file is `~/.config/pipcast/settings.json`, with `pipcast-beta` and
`pipcast-dev` folders for those channels. Existing Tinycast settings are not migrated automatically.
Backups export as `.pipcast`; importing existing `.tinycast` backups remains supported.

## Contribute

Report bugs and suggestions in [Issues](https://github.com/mSarheed/pipcast/issues).
See [CONTRIBUTING.md](CONTRIBUTING.md) and [the developer docs](docs/README.md).
Pipcast has no donation checkout or paid features.
