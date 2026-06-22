# Building & Distribution

This guide covers building for development and creating distribution builds.

## Development Builds

### Generate Xcode Project

Always regenerate after modifying `project.yml`:

```bash
xcodegen generate
```

### Mac App (Debug)

```bash
# Build
just build-mac

# Build and run
just run-mac
```

### iOS App (Debug)

```bash
# Simulator
just build-sim

# Physical device (set XCODE_DEVICE_ID and DEVICECTL_ID in .env)
just build-ios
just run-ios
```

## Distribution Builds

### iOS App Store

The iOS app is distributed via App Store Connect:

```bash
# Archive and upload to App Store Connect
just release-ios
```

This creates an archive and uploads to App Store Connect. Then:
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select the build for TestFlight or App Review

### Mac DMG (GitHub Releases)

The Mac app is distributed as a signed and notarized DMG.

#### One-time Setup

1. **Create Developer ID Certificate**
   - Go to [Apple Developer Portal](https://developer.apple.com/account/resources/certificates/list)
   - Create "Developer ID Application" certificate
   - Download and install in Keychain

2. **Create App-Specific Password**
   - Go to [appleid.apple.com](https://appleid.apple.com)
   - Security → App-Specific Passwords → Generate

3. **Store Notarization Credentials**
   ```bash
   just setup-notary
   # Enter your Apple ID and app-specific password
   ```

#### Release Workflow

```bash
# Verify signing setup
just check-signing

# Full release: build, sign, notarize, create DMG
just release-mac
```

The pipeline:
1. Build Release configuration with Hardened Runtime
2. Create DMG with app
3. Sign DMG with Developer ID
4. Submit to Apple for notarization
5. Staple notarization ticket to DMG

Output: `./build/Deck-{version}.dmg`

#### Individual Commands

```bash
just dmg                    # Create unsigned DMG
just sign-dmg               # Sign DMG
just notarize               # Submit for notarization
just verify-signing         # Verify app signature
just verify-notarization    # Verify DMG is notarized
just notary-log             # Show notarization history
```

#### Create GitHub Release

```bash
gh release create v1.0 \
  ./build/Deck-1.0.dmg \
  --title 'Deck v1.0' \
  --notes 'Release notes here'
```

## Homebrew Distribution

Deck's cask lives in the shared **`douinc/homebrew-tap`** repo (`Casks/deck.rb`), alongside the legacy `clicker-remote-receiver` cask — one tap serves both products. The cask is no longer shipped from this repo.

### Update Cask for New Release

After building the DMG (`just release-mac`) and creating the GitHub release, refresh the cask:

```bash
just update-tap
```

This dispatches the `update-deck-cask` workflow in `douinc/homebrew-tap`, which downloads the published `Deck-<version>.dmg`, recomputes its SHA256, updates `Casks/deck.rb` (version + sha256), and commits/pushes — all in the tap repo. Requires `gh` auth with workflow access to `douinc/homebrew-tap`.

### Install from Tap

```bash
brew tap douinc/tap
brew install --cask deck
```

> The repo `douinc/homebrew-tap` resolves to the tap name `douinc/tap` (Homebrew strips the `homebrew-` prefix). The old standalone `douinc/deck` tap is retired. Because the cask runs a `postflight` (it opens the Accessibility pane), Homebrew may ask you to trust the tap once: `brew trust douinc/tap`.

## Build Configuration

### project.yml Key Settings

```yaml
targets:
  DeckMac:
    settings:
      base:
        ENABLE_HARDENED_RUNTIME: YES
      configs:
        Release:
          CODE_SIGN_STYLE: Manual
          CODE_SIGN_IDENTITY: "Developer ID Application"
          CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO
          OTHER_CODE_SIGN_FLAGS: "--timestamp"
```

### Why These Settings?

| Setting | Purpose |
|---------|---------|
| `ENABLE_HARDENED_RUNTIME` | Required for notarization |
| `CODE_SIGN_IDENTITY` | Use Developer ID (not Apple Distribution) |
| `CODE_SIGN_INJECT_BASE_ENTITLEMENTS` | Prevent debug entitlements |
| `--timestamp` | Required for notarization verification |

## justfile Reference

```bash
just                        # Show all commands

# Development
just generate               # Generate Xcode project
just build-mac              # Build Mac (debug)
just build-ios              # Build iOS for device
just build-sim              # Build iOS for simulator
just run-mac                # Build and run Mac
just run-ios                # Build, install, launch iOS on device
just deploy                 # Deploy iPhone + Watch to device

# Mac Distribution
just check-signing          # Verify Developer ID cert
just setup-notary           # Store notarization creds
just release-mac            # Full release pipeline
just dmg                    # Create DMG only
just sign-dmg               # Sign DMG
just notarize               # Notarize DMG
just verify-signing         # Verify signature
just verify-notarization    # Verify notarization

# iOS Distribution
just release-ios            # Archive and upload to ASC
```
