# Building & Distribution

Development builds, release pipelines, the Homebrew cask, and the website and marketing assets. Run `just` to list every command.

## Development builds

Regenerate the Xcode project after any change to `project.yml`:

```bash
just generate
```

> `just generate` rewrites the Info.plist files from `project.yml`, including the version numbers. Set versions in `project.yml`.

| Command | What it does |
|---------|--------------|
| `just build-mac` | Debug build of the Mac app |
| `just run-mac` | Build and open the Mac app |
| `just install-mac` | Release build installed into `/Applications` |
| `just build-sim` / `just run-sim` | Build / build and run the iPhone app in the simulator |
| `just build-ios` | Build for the device in `XCODE_DEVICE_ID` |
| `just install-ios` / `just run-ios` | Install / install and launch on the device in `DEVICECTL_ID` |
| `just deploy` | Install iPhone + Watch apps on the device |
| `just uninstall-ios` | Remove the app and its data from the device |
| `just clean-install-ios` | Uninstall, clean, build, install |
| `just screenshot` | Simulator build with `SCREENSHOT_MODE` (no trial banner) |
| `just regen-icons` | Regenerate app icons and logos from `deck-logo.png` (needs ImageMagick) |
| `just clean` | Clean build products, unmount the DMG volume, remove `/Applications/Deck.app` (uses sudo) |
| `just list-devices` | List connected devices |

## Versioning

All four targets carry the same version. To bump it, change `CFBundleShortVersionString` and `MARKETING_VERSION` for every target in `project.yml`, then run `just generate`. The justfile reads the version for DMG names from `MacApp/Info.plist`.

## iPhone and Apple Watch: App Store

```bash
just release-ios     # archive-ios + upload-ios
```

This archives the `DeckiOS` scheme (which embeds the watch app and the Live Activity extension) and uploads it with `ExportOptions.plist`. Then choose the build for TestFlight or review in [App Store Connect](https://appstoreconnect.apple.com).

## Mac: signed and notarized DMG

### One-time setup

1. **Developer ID certificate.** Create a "Developer ID Application" certificate in the [Apple Developer portal](https://developer.apple.com/account/resources/certificates/list) and install it. Check with `just check-signing`.
2. **App-specific password.** Generate one at [appleid.apple.com](https://appleid.apple.com).
3. **Notary credentials.** `just setup-notary` stores them in the keychain as `notarytool-profile`.

### Release

```bash
just release-mac
```

The pipeline:

1. Build the Release configuration with Hardened Runtime
2. Create the DMG with the custom volume icon and an Applications link
3. Sign the DMG with the Developer ID
4. Submit to Apple for notarization and wait
5. Staple the notarization ticket

Output: `./build/Deck-{version}.dmg`

Each stage is also its own command:

```bash
just build-mac-release      # Release build
just verify-signing         # Check signature, identity and Hardened Runtime
just dmg                    # Unsigned DMG
just sign-dmg               # Signed DMG
just notarize               # Notarize and staple
just verify-notarization    # Gatekeeper and stapler checks
just notary-log             # Notarization history
```

### Publish

The asset must be named `Deck-{version}.dmg` to match the cask URL.

```bash
gh release create v2.0.0 ./build/Deck-2.0.0.dmg --title 'Deck v2.0.0' --notes 'Release notes'
just update-tap
```

The Mac app checks the latest GitHub release once a day and shows "Update Available" in its menu when the tag is newer than the running version, so tag names must be `v` followed by the version.

### CI alternative

`.github/workflows/release.yml` runs when a `v*` tag is pushed. It archives the Mac app, exports it with a Developer ID, notarizes and staples the app, wraps it in a plain DMG named `Deck-{version}.dmg`, and creates the GitHub release. It needs the repository secrets `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `KEYCHAIN_PASSWORD`, `APPLE_ID` and `APPLE_APP_SPECIFIC_PASSWORD`. Unlike `just release-mac`, the CI DMG has no custom volume icon or Applications link.

## Homebrew cask

Deck's cask lives in the shared **`douinc/homebrew-tap`** repository (`Casks/deck.rb`), alongside the legacy `clicker-remote-receiver` cask. It is not shipped from this repository.

```bash
just update-tap
```

This dispatches the `update-deck-cask` workflow in `douinc/homebrew-tap`, which downloads the published `Deck-{version}.dmg`, recomputes its SHA256, updates the cask and pushes. It needs the GitHub release to exist and `gh` auth with workflow access to the tap.

Users install with:

```bash
brew tap douinc/tap
brew install --cask deck
```

> The repository `douinc/homebrew-tap` resolves to the tap name `douinc/tap`. The cask runs a `postflight` that opens the Accessibility pane, so Homebrew may ask the user to trust the tap once: `brew trust douinc/tap`. The old standalone `douinc/deck` tap is retired; existing users should `brew untap douinc/deck` and tap `douinc/tap`.

## Build configuration

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

| Setting | Purpose |
|---------|---------|
| `ENABLE_HARDENED_RUNTIME` | Required for notarization |
| `CODE_SIGN_IDENTITY` | Developer ID, not Apple Distribution |
| `CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO` | Keeps the debug entitlement out of Release builds |
| `--timestamp` | Required for notarization |

Info.plist keys belong in each target's `info.properties` in `project.yml`. MultipeerConnectivity needs `NSBonjourServices` and `NSLocalNetworkUsageDescription` on both the Mac and iPhone targets; the iPhone also needs `NSSupportsLiveActivities`, and the watch needs `NSMotionUsageDescription` and the `self-care` background mode.

## Website and marketing assets

The landing page, the App Store panels and the film share one look: Archivo set condensed, on fields in the app's own timer tints (mint `#8fedcc`, amber `#ffd17a`, orange `#ff9e5c`, coral `#ff6b66`), with the thumb arcs extended across each field.

| Asset | Source | Output |
|-------|--------|--------|
| Landing page | `index.html` | [deck.dou.so](https://deck.dou.so) |
| Support page | `support/index.html` | [deck.dou.so/support](https://deck.dou.so/support) |
| Privacy and terms | `PRIVACY_POLICY.html`, `TERMS_OF_SERVICE.html` | Linked from the site and the paywall |
| Web captures and font | `public/web/` | Used by the site |
| App Store panels | `marketing/appstore/index.html`, `style.css`, `rings.js`, `captures/` | `marketing/appstore/out/iphone-6.9`, `-6.5`, `-6.3`, `overview.png` |
| README images | `marketing/appstore/out/iphone-6.9/*.png` | `public/readme/*.webp` |
| Film | `video/` | [youtu.be/bQY4ZfCDE-s](https://youtu.be/bQY4ZfCDE-s) |
| App icons and logos | `deck-logo.png` | `just regen-icons` |

The site is static and served from the repository root; `CNAME` maps it to `deck.dou.so`.

Render the App Store panels (needs Google Chrome and ImageMagick):

```bash
marketing/appstore/render.sh
```

Refresh the README images after re-rendering the panels:

```bash
for f in marketing/appstore/out/iphone-6.9/*.png; do
  magick "$f" -resize 600x -quality 86 "public/readme/$(basename "${f%.png}").webp"
done
```

## Wiki

The wiki's source is the `wiki/` directory. `.github/workflows/wiki-sync.yml` copies it to the GitHub wiki on every push to `main` that touches `wiki/**`. Edit the files here, not in the GitHub wiki UI; the sync replaces the wiki's contents.
