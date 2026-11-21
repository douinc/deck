# Getting Started

Set up a development environment and run all three apps from source.

## Prerequisites

| Requirement | Version | Install |
|-------------|---------|---------|
| macOS | 14.0+ (Sonoma) | — |
| Xcode | 16.0+ | App Store or [developer.apple.com](https://developer.apple.com/xcode/) |
| XcodeGen | Latest | `brew install xcodegen` |
| just | Latest | `brew install just` |
| Apple Developer account | — | Needed to run on a physical iPhone or Apple Watch |

## Clone and generate

```bash
git clone https://github.com/douinc/deck.git
cd deck
just generate          # xcodegen generate → Deck.xcodeproj
open Deck.xcodeproj    # optional
```

`Deck.xcodeproj` is generated and git-ignored. Change `project.yml`, never the project file. The project has four targets:

| Target | Platform | Scheme |
|--------|----------|--------|
| `DeckMac` | macOS | `DeckMac` |
| `DeckiOS` | iOS | `DeckiOS` (also builds the two below) |
| `DeckWatch` | watchOS | `DeckWatch` |
| `DeckLiveActivity` | iOS widget extension | built by `DeckiOS` |

## Run the Mac app

```bash
just run-mac        # Debug build, then open it
just install-mac    # Release build into /Applications
```

The Mac app appears in the menu bar and opens its setup guide on first launch. It needs Accessibility permission to press keys and move the cursor. Each rebuilt binary can lose that permission in System Settings; if slides stop changing after a rebuild, remove Deck from the Accessibility list and add it again.

## Run the iPhone app

### Simulator

```bash
just run-sim
```

The pointer needs real motion sensors, so test it on a device. To work on the remote's layout without a Mac, pass launch arguments to a Debug build:

| Launch argument | Effect |
|-----------------|--------|
| `-previewRemote` | Open straight into the remote, without a connection |
| `-previewArranging` | Open the remote in Arrange Buttons mode |
| `-previewLimit <seconds>` | Stage a time limit |
| `-previewElapsed <seconds>` | Stage elapsed time |

```bash
xcrun simctl launch booted com.dou.clicker-ios -previewRemote -previewLimit 1200 -previewElapsed 462
```

`just screenshot` builds with the `SCREENSHOT_MODE` compilation condition, which forces a subscribed state so the trial banner is hidden.

### Physical device

1. Connect the iPhone and find its identifiers:
   ```bash
   xcrun devicectl list devices
   just list-devices
   ```
2. Copy `.env.template` to `.env` and fill it in:
   ```bash
   XCODE_DEVICE_ID=<xcodebuild UDID>
   DEVICECTL_ID=<devicectl UUID>
   ```
3. Build, install and launch:
   ```bash
   just run-ios
   ```

`just deploy` installs the iPhone app with the embedded watch app. The watch app then syncs to the paired Apple Watch. If it does not appear, open the Watch app on the iPhone → My Watch → Installed Apps.

## Use your own development team

If you see "Signing requires development team":

1. Open `project.yml`
2. Replace `HD35YQ72U4` with your Team ID in every target
3. Run `just generate`

Find your Team ID:

```bash
security find-identity -v -p codesigning
```

## Testing purchases

The `DeckiOS` scheme points at `iPhoneApp/Deck.storekit` as its StoreKit configuration. That file is git-ignored, so create your own in Xcode with a yearly auto-renewable subscription whose product ID is `com.dou.clicker_ios.subscription.yearly`.

The trial start date lives in the Keychain and survives deleting the app. See [[Troubleshooting]] for resetting it.

## Next steps

- [[Architecture]]: how the apps talk to each other
- [[API-Reference]]: wire protocol and key classes
- [[Building]]: release builds and distribution
