# Getting Started

This guide covers setting up your development environment to build Deck from source.

## Prerequisites

| Requirement | Version | Installation |
|-------------|---------|--------------|
| macOS | 14.0+ (Sonoma) | — |
| Xcode | 16.0+ | App Store or [developer.apple.com](https://developer.apple.com/xcode/) |
| XcodeGen | Latest | `brew install xcodegen` |
| Apple Developer Account | — | Required for device deployment |

## Clone & Setup

```bash
# Clone the repository
git clone https://github.com/douinc/deck.git
cd deck

# Generate Xcode project
xcodegen generate

# Open in Xcode (optional)
open Deck.xcodeproj
```

## Build Mac App

```bash
# Debug build
just build-mac

# Or directly with xcodebuild
xcodebuild -scheme DeckMac -configuration Debug build

# Run the app
just run-mac
```

The Mac app will appear in your menu bar.

## Build iOS App

### Simulator

```bash
just build-sim

# Or with specific simulator
xcodebuild -scheme DeckiOS \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' \
  build
```

### Physical Device

1. Connect your iPhone via USB
2. List available devices:
   ```bash
   xcrun devicectl list devices
   ```
3. Set device IDs in `.env` file:
   ```bash
   XCODE_DEVICE_ID=<your-xcode-device-udid>
   DEVICECTL_ID=<your-devicectl-uuid>
   ```
4. Build and install:
   ```bash
   just run-ios
   ```

## Development Team Setup

If you see "Signing requires development team" errors:

1. Open `project.yml`
2. Replace `HD35YQ72U4` with your Team ID
3. Regenerate: `xcodegen generate`

Find your Team ID:
```bash
security find-identity -v -p codesigning | grep "Developer ID"
```

## Next Steps

- [[Architecture]] — Understand how the apps work together
- [[Building]] — Learn about distribution builds
- [[API-Reference]] — Explore the codebase
