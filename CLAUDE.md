# Claude Code Instructions for Deck

## Project Overview

This is a SwiftUI-based presentation remote system with three apps:
- Mac App (`Deck` v1.12): Menu bar app that receives commands and sends keystrokes to presentation software
- iPhone App (`Deck` v1.12): Remote control with vertical slide navigation and presentation timer
- Apple Watch App (`DeckWatch` v1.12): Companion watch app with gesture-based slide control using double tap motion for next slide

## Tech Stack

- Language: Swift 5.9
- UI Framework: SwiftUI
- Networking: MultipeerConnectivity (Mac↔iPhone), WatchConnectivity (iPhone↔Watch)
- Build System: XcodeGen + xcodebuild (CLI-based, no Xcode GUI required)
- Platforms: macOS 14.0+, iOS 18.0+, watchOS 10.0+
- Design: Apple liquid glass aesthetic (dark mode, translucent materials)

## Documentation

Use GitHub wiki as the main source of developer documentation. The documentation is in `./wiki/`.

## Project Structure

```
deck/
├── MacApp/              # macOS menu bar receiver app
├── iPhoneApp/           # iOS remote control app
├── WatchApp/            # Apple Watch companion app
├── Shared/              # Shared code (RemoteCommand.swift)
├── wiki/                # GitHub wiki documentation
├── public/              # Logos and screenshots
├── build/               # Build artifacts
├── .github/             # GitHub Actions workflows
├── project.yml          # XcodeGen project configuration
└── justfile             # Build and deployment commands
```

## Build Commands

Reference @justfile

## Distribution

### iOS and Apple Watch App (App Store)

The iOS and companion Apple Watch app is distributed via the App Store.

Then go to App Store Connect to select the build for TestFlight/review.

### Mac App (GitHub DMG - Signed & Notarized)

The Mac app is distributed as a signed and notarized DMG via GitHub Releases.

The full pipeline:
1. Build Release configuration with Hardened Runtime
2. Create DMG with custom icon
3. Sign DMG with Developer ID
4. Submit to Apple for notarization
5. Staple notarization ticket to DMG

The notarized DMG is created at `./build/Deck-{version}.dmg`.

Create GitHub release and update Homebrew tap:
```bash
# Create the release (the asset MUST be named Deck-{version}.dmg to match the cask URL)
gh release create v1.12 ./build/Deck-1.12.dmg --title 'Deck v1.12' --notes 'Release notes'

# Refresh the deck cask in the shared douinc tap (auto-calculates SHA256)
just update-tap
```

Deck's Homebrew cask lives in the shared `douinc/homebrew-tap` repo
(`Casks/deck.rb`), alongside the legacy `clicker-remote-receiver` cask — a single
tap serves both products. The deck cask is NOT shipped from this repo anymore.
The `update-tap` command:
1. Triggers the `update-deck-cask` workflow in `douinc/homebrew-tap` via `gh workflow run`
2. That workflow downloads the published `Deck-{version}.dmg` from this repo's GitHub release
3. Recomputes the SHA256, updates `Casks/deck.rb` (version + sha256), and commits/pushes

Requires `gh` auth with workflow access to `douinc/homebrew-tap`, and the GitHub
release to exist first. The release workflow (`.github/workflows/release.yml`) can
also auto-refresh the cask by sending a `repository_dispatch` (type `deck-release`)
to the tap.

Users install with:
```bash
brew tap douinc/tap
brew install --cask deck
# If Homebrew reports an untrusted tap (the cask runs a postflight to open the
# Accessibility pane), trust it once:
brew trust douinc/tap
```

> Tap naming: the repo is `douinc/homebrew-tap`, which Homebrew resolves as the
> tap `douinc/tap` (the `homebrew-` prefix is stripped). The old standalone
> `douinc/deck` tap is retired; existing users should `brew untap douinc/deck`
> and re-tap `douinc/tap`.

## Key Architecture Decisions

### XcodeGen Configuration
- `project.yml` defines all three targets (Mac, iOS, Watch) in a single unified project
- Info.plist keys are specified in `info.properties` section (not just `info.path`)
- This is critical for Multipeer Connectivity which requires `NSBonjourServices` and `NSLocalNetworkUsageDescription`
- The Watch app is embedded in the iOS target via `dependencies`

### Multipeer Connectivity (Mac↔iPhone)
- Service type: `_clickerremote._tcp` and `_clickerremote._udp`
- Mac acts as advertiser, iPhone acts as browser
- Commands are sent as JSON-encoded `RemoteCommand` enum values
- Shared config in `Shared/RemoteCommand.swift`

### WatchConnectivity (iPhone↔Watch)
- iPhone relays Watch commands to Mac via MultipeerConnectivity
- Watch sends commands using `WCSession.default.sendMessage`

### Mac App Specifics
- App name: `Deck` (distributed via GitHub DMG)
- Bundle ID: `com.dou.clicker-mac`
- `LSUIElement: true` makes it a menu bar app (no Dock icon)
- Requires Accessibility permission for CGEvent keystroke injection
- Uses `CGEvent` API to send keyboard events to frontmost app

### iPhone App Specifics
- App name: `Deck` (distributed via App Store)
- Bundle ID: `com.dou.clicker-ios`
- Vertical button layout: Previous (chevron up) at top, Next (chevron down) at bottom
- Liquid glass aesthetic using `.ultraThinMaterial` for frosted glass effect
- Dark mode only (`.preferredColorScheme(.dark)`) for stage visibility
- Timer uses `UIImpactFeedbackGenerator` for haptic feedback
- In-App Purchase capability for subscription/trial

### Apple Watch App Specifics
- App name: `DeckWatch` (embedded in iOS app, distributed via App Store)
- Bundle ID: `com.dou.clicker-ios.watchkitapp`
- Double-tap gesture via `handGestureShortcut(.primaryAction)` on watchOS 11+ (Apple Watch Series 9+ / Ultra 2) for next slide
- Note: Double-tap requires active display (wrist raised); does not work in always-on / luminance-reduced state
- Wrist flick mode uses CoreMotion gyroscope (`rotationRate.x`) to detect forward/backward wrist flicks for next/previous slide
- "No Going Back" toggle (`gestureNoGoingBack` in UserDefaults) disables backward flick gestures for forward-only navigation, reducing accidental triggers during presentations
- Flick mode settings: gesture lock (3s cooldown), invert gestures, auto-toggle with wrist raise, no going back
- Extended WatchKit runtime session (`WKExtendedRuntimeSession` with `self-care` background mode) keeps app active during presentations

## Development Team

Team ID: `HD35YQ72U4` (DOU Inc.)

## When Modifying This Project

1. Edit Swift source files directly
2. If changing build settings, targets, or Info.plist keys, edit `project.yml`
3. Run `just generate` after modifying `project.yml` to regenerate the Xcode project
  - Note that this overrides the version information.

## Useful Debugging Commands

```bash
# Check built Info.plist contents
find ~/Library/Developer/Xcode/DerivedData/Deck-*/Build/Products -name "Info.plist" -exec plutil -p {} \;

# List available schemes
xcodebuild -project Deck.xcodeproj -list

# Show build destinations
xcodebuild -scheme DeckiOS -showdestinations

# Find Team ID
security find-identity -v -p codesigning

# List connected iOS devices
xcrun devicectl list devices

# List available simulators
xcrun simctl list devices available
```
