# ClaudePilot

![Platform](https://img.shields.io/badge/platform-macOS-000000?logo=apple&logoColor=white) ![macOS](https://img.shields.io/badge/macOS-14.0%2B-0A84FF) ![Language](https://img.shields.io/badge/language-Swift-F05138?logo=swift&logoColor=white) ![Build](https://img.shields.io/github/actions/workflow/status/sha2kyou/ClaudePilot/build.yml?event=push) ![Release](https://img.shields.io/github/v/release/sha2kyou/ClaudePilot?display_name=tag)

ClaudePilot is a macOS menu bar application for managing multiple Claude API profiles and applying the selected profile into local Claude CLI settings.

## Scope

- This repository ships source code only.
- App source lives in `ClaudePilot/`.
- Xcode project: `ClaudePilot.xcodeproj`.

## Features

- Manage multiple profiles (name, base URL, model, API key, optional auth token, custom env entries).
- Persist profiles to local app support JSON (see Data and Storage).
- Edit profile details in the configuration window.
- Select active profile from menu bar and apply to `~/.claude/settings.json`.

## Requirements

- macOS 14.0+
- Xcode version capable of building this project

## Installation

### Recommended: Homebrew Cask

```bash
brew tap sha2kyou/tap
brew install --cask claudepilot
```

### Alternative: Download DMG from Release

1. Download `ClaudePilot-vX.Y.Z.dmg` from [Releases](https://github.com/sha2kyou/ClaudePilot/releases).
2. Drag `ClaudePilot.app` into `/Applications`.

## Quick Start (Build from source)

1. Open `ClaudePilot.xcodeproj` in Xcode.
2. Select the `ClaudePilot` scheme and run.
3. Add one or more profiles from the config window.
4. Switch active profile from menu bar.

## Data and Storage

- Profile state (including API key and auth token): `~/Library/Application Support/ClaudePilot/profiles.json` (JSON on disk).
- Applied runtime target file: `~/.claude/settings.json` (may mirror env values from the active profile).

## Security Notes

- Treat `profiles.json` and `~/.claude/settings.json` as sensitive; do not commit them, sync them to untrusted hosts, or share copies casually.
- If you use Git in your home directory or backup tools, exclude these paths or verify they are not archived into public artifacts.

## Gatekeeper (Unsigned Builds)

When running unsigned builds on other macOS machines, Gatekeeper may block launch (for example, "Developer cannot be verified" or "App is damaged").

If Gatekeeper blocks launch on unsigned builds, advanced users can try right-click **Open**. You can also remove quarantine attributes manually:

```bash
xattr -dr com.apple.quarantine /Applications/ClaudePilot.app
```

When installed via Homebrew cask from `sha2kyou/tap`, this command is automatically executed in `postflight`.

## Build and Release

- GitHub Actions workflow: `.github/workflows/build.yml`
- Trigger: push tag matching `v*`
- Output: `.dmg` artifact and GitHub Release asset

## License

Apache-2.0. See `LICENSE`.
