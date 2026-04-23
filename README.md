# ClaudePilot

![Platform](https://img.shields.io/badge/platform-macOS-000000?logo=apple&logoColor=white) ![macOS](https://img.shields.io/badge/macOS-14.0%2B-0A84FF) ![Language](https://img.shields.io/badge/language-Swift-F05138?logo=swift&logoColor=white) ![Build](https://img.shields.io/github/actions/workflow/status/sha2kyou/ClaudePilot/build.yml?branch=main) ![Release](https://img.shields.io/github/v/release/sha2kyou/ClaudePilot?display_name=tag)

ClaudePilot is a macOS menu bar application for managing multiple Claude API profiles and applying the selected profile into local Claude CLI settings.

## Scope

- This repository ships source code only.
- App source lives in `ClaudePilot/`.
- Xcode project: `ClaudePilot.xcodeproj`.

## Features

- Manage multiple profiles (name, base URL, model, API key).
- Store API keys in macOS Keychain (per profile).
- Edit profile details in the configuration window.
- Select active profile from menu bar and apply to `~/.claude/settings.json`.
- Keep profile list in local app support storage.

## Requirements

- macOS 14.0+
- Xcode version capable of building this project

## Quick Start

1. Open `ClaudePilot.xcodeproj` in Xcode.
2. Select the `ClaudePilot` scheme and run.
3. Add one or more profiles from the config window.
4. Switch active profile from menu bar.

## Data and Storage

- Profile metadata file: `~/Library/Application Support/ClaudePilot/profiles.json`
- API keys: stored in macOS Keychain
- Applied runtime target file: `~/.claude/settings.json`

## Security Notes

- API keys are not stored in plain text files by the app.
- `~/.claude/settings.json` can contain API-related environment values after apply. Treat it as sensitive.

## Gatekeeper (Unsigned Builds)

When running unsigned builds on other macOS machines, Gatekeeper may block launch (for example, "Developer cannot be verified" or "App is damaged").

For local testing, advanced users can try right-click **Open**, or remove quarantine attributes:

```bash
xattr -dr com.apple.quarantine /Applications/ClaudePilot.app
```

This workaround is not suitable for production distribution.

## Build and Release

- GitHub Actions workflow: `.github/workflows/build.yml`
- Trigger: push tag matching `v*`
- Output: zipped `.app` artifact and GitHub Release asset

## License

Apache-2.0. See `LICENSE`.
