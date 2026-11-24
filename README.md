# IntelliTile

A native macOS utility that lets you create custom Dock tiles to organise and launch your favourite apps with a single click.

![macOS 15.0+](https://img.shields.io/badge/macOS-15.0+-blue.svg)
![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)
![Intel x86_64](https://img.shields.io/badge/Intel-x86__64-lightgrey.svg)

## Intel Mac port (unofficial)

IntelliTile is an **unofficial** port of the open-source project
[k97/dock-tile](https://github.com/k97/dock-tile) (MIT licence) to **Intel (x86_64) Macs running
macOS Sequoia 15**. The original project supports Apple silicon only; all credit for the app goes to
its author, k97, and contributors. This fork is not affiliated with or endorsed by them, and it
ships under its own name, icon and bundle identifiers as the original's
[TRADEMARKS.md](TRADEMARKS.md) requires.

What is different from the original:

- An x86_64 build made by this fork's CI (GitHub Intel runner), ad-hoc signed and not notarized, is
  published on this fork's [Releases](https://github.com/efczpaclasses-boop/IntelliTile/releases);
  no official DMG is used. Building from source with Xcode (`./install.sh`) stays optional.
- New name (IntelliTile), new icon and new bundle IDs (`io.github.efczpaclasses-boop.IntelliTile`),
  so it cannot collide with the official app.
- The official Sparkle auto-updater is removed; update with `./update.sh` (downloads the newest
  fork release and checks its SHA-256).
  **Check for Updates** only asks this fork's GitHub Releases whether a newer build exists and offers to
  open its release page; nothing is downloaded or installed. Fork releases are tagged `vX.Y.Z` or
  `vX.Y.Z-intel.N` (N = Intel build of that version); the release workflow stamps the tag into the app,
  so 2.8.1-intel.1 < 2.8.1-intel.2 < 2.8.2. A build from source has no stamp and is only offered a newer X.Y.Z.
- Firebase analytics and crash reporting are switched off by default and no Firebase project is
  bundled, so nothing is sent.
- The Rust icon compiler is optional on Sequoia (it is only used on macOS 26).
- macOS 26 (Tahoe) icon styles / Liquid Glass are not available on Sequoia.

Every change is listed in [CHANGES.md](CHANGES.md); test results are in [TESTLOG.md](TESTLOG.md).
The `website/` and `docs/` folders are the original project's own material, kept unchanged for
easier merging; they describe the original app, not this port, and are not published by this fork.

## Overview

IntelliTile brings the power of custom app launchers to your macOS Dock. Create multiple tiles, each with its own curated list of apps, custom icon, and colour scheme. Click a tile to reveal a beautiful popover with your apps ready to launch.

Think of it as customisable Dock folders - with native vibrancy effects, SF Symbols, emoji icons, and the polish you'd expect from a first-party macOS app.

## Features

- **Multiple Tiles** - Create as many dock tiles as you need, each completely independent
- **Custom Icons** - Show the tile's own apps as an App Grid, or choose an SF Symbol or any emoji
- **Colour Themes** - Pick from 7 preset gradient colours or create your own, on a Colour or Mono background
- **Adjustable Icon Size** - Fine-tune the icon size with the built-in scale control
- **Flexible Layouts** - Display apps in a grid or list view
- **Smart Add** - Suggests ready-made tiles from the apps you use, learned on your Mac and never sent anywhere
- **Native Experience** - Built with SwiftUI and AppKit for an authentic macOS look and feel
- **Dock Integration** - Tiles appear in the Dock just like regular apps
- **App Switcher Support** - Optionally show tiles in Cmd+Tab
- **Dock Lock** - Keep the Dock on one display on multi-monitor setups
- **Start at Login** - Tiles are ready the moment you log in (IntelliTile: off until you turn it on in Settings)

## Requirements

- An Intel (x86_64) Mac on macOS Sequoia 15.6 or later (15.0 is the app's floor; 15.6 is what Xcode 26 needs to build it)
- Full Xcode 26.2 or 26.3 (Universal) from Apple, not Xcode 26.4+ (needs Tahoe) or Xcode 27 (Apple silicon only)
- No Rust toolchain needed on Sequoia

## Installation

### Intel Mac: CI-built release (no Xcode needed)

1. Download `IntelliTile-<version>-x86_64.zip` and its `.zip.sha256` from this fork's
   [Releases](https://github.com/efczpaclasses-boop/IntelliTile/releases) page.
2. Check it: `cd ~/Downloads && shasum -a 256 -c IntelliTile-<version>-x86_64.zip.sha256`
3. Unzip it and move `IntelliTile.app` to `~/Applications` (no admin rights needed).
4. The app is ad-hoc signed, not notarized, so macOS blocks the first open. Open it once, then use
   System Settings > Privacy & Security > Open Anyway.

Later updates (no Xcode, no admin rights): from a clone of this branch, run `./update.sh`. It downloads
the newest release, checks the SHA-256, signature and architecture, and replaces only
`~/Applications/IntelliTile.app`. Quit IntelliTile first.

### From Source (optional, needs Xcode)

```bash
mkdir -p ~/IntelPorts/dock-tile
git clone --branch intel-x86_64 https://github.com/efczpaclasses-boop/IntelliTile.git ~/IntelPorts/dock-tile/src
cd ~/IntelPorts/dock-tile/src
./install.sh                 # builds x86_64 Release and installs ~/Applications/IntelliTile.app
./update.sh --from-source    # later: fast-forward pull of intel-x86_64, then rebuild
./install.sh --uninstall
```

## Getting Started

1. **Launch IntelliTile** - Open the app from your Applications folder
2. **Create a Tile** - Click the "+" button in the sidebar, then pick a Smart Add suggestion or "Create New Tile"
3. **Add Apps** - Click "Add" in the In This Tile section to add apps and folders
4. **Customise** - Click the tile's icon (or the Customise Tile toggle in the toolbar) to choose its style, icon and colour
5. **Add to Dock** - Click "Add to Dock" to pin the tile
6. **Use It** - Click your new tile in the Dock to see your apps!

## How It Works

IntelliTile creates lightweight helper applications for each tile you configure. These helpers appear as independent apps in the Dock and show a native popover when clicked.

## Tile Settings

| Setting | Description |
|---------|-------------|
| Tile Name | Display name shown below the Dock icon |
| Show Tile | Toggle visibility in the Dock |
| Layout | Choose between Grid or List view |
| Show in App Switcher | Include tile in Cmd+Tab |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Click tile | Open popover |
| Arrow keys | Navigate apps in popover |
| Return | Launch selected app |
| Escape | Close popover |

## Troubleshooting

### Tile doesn't appear in the Dock
1. Ensure "Show Tile" is toggled on
2. Click "Add to Dock" to apply changes

### Icon not updating
Click "Update" on the tile to rebuild it. The button is highlighted while the Dock shows an older version of the tile.

## Translations

IntelliTile ships in English, 简体中文, 日本語, Deutsch, Русский and Français. The non-English
translations are machine-first and reviewed by native speakers. Spotted a mistake? Fixing it takes
five minutes in the browser — see [docs/l10n/README.md](docs/l10n/README.md).

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development documentation.

```bash
# Build
xcodebuild -project DockTile.xcodeproj -scheme DockTile build

# Clean
xcodebuild -project DockTile.xcodeproj -scheme DockTile clean
```

## Testing

Run the test suite to verify everything works:

```bash
# Run all unit tests
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' -only-testing:DockTileTests

# Run with code coverage
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' -enableCodeCoverage YES
```

Or in Xcode: Press **Cmd+U** to run all tests.

On this fork, tests run on GitHub's Intel macOS runner (`.github/workflows/intel-macos.yml`).

## License

IntelliTile is based on the original project's source code, released under the [MIT License](LICENSE) (Copyright 2026 k97). The original project's trademark notice, which this fork follows: The Dock Tile name, logo
and app icon are not licensed for use by other software — see [TRADEMARKS.md](TRADEMARKS.md). The
vendored icon compiler under `Vendor/actool/` declares MIT in its `Cargo.toml` (upstream ships no
LICENSE file; see `Vendor/actool/DOCKTILE-README.md`).

---

Made with care for macOS
