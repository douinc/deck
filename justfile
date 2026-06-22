# Deck - Presentation Remote System
# Run `just` to see available commands

set shell := ["bash", "-uc"]
set dotenv-load

# Find the most recently modified DerivedData folder
derived_data := `ls -td ~/Library/Developer/Xcode/DerivedData/Deck-* 2>/dev/null | head -1`
mac_app := derived_data + "/Build/Products/Debug/Deck.app"
release_mac_app := derived_data + "/Build/Products/Release/Deck.app"
ios_app := derived_data + "/Build/Products/Debug-iphoneos/Deck.app"
ios_sim_app := derived_data + "/Build/Products/Debug-iphonesimulator/Deck.app"

# Version from Info.plist
version := `/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" MacApp/Info.plist 2>/dev/null || echo "1.0.0"`

dmg_name := "Deck"
mac_logo := "public/logo/mac-logo.png"
notary_profile := "notarytool-profile"
signing_identity := "Developer ID Application: DOU Inc. (HD35YQ72U4)"

# ─────────────────────────────────────────────────────────────────────────────
# Development
# ─────────────────────────────────────────────────────────────────────────────

# Show available commands
default:
    @just --list

# Generate Xcode project from project.yml
generate:
    xcodegen generate

# Regenerate all app icons + marketing logos from deck-logo.png
# App icons are flattened onto white (no alpha — required by the App Store);
# public/logo/*.png keep transparency for the DMG/marketing use.
regen-icons:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v magick >/dev/null || { echo "❌ ImageMagick not found (brew install imagemagick)"; exit 1; }
    SRC="deck-logo.png"
    [ -f "$SRC" ] || { echo "❌ $SRC not found"; exit 1; }

    opaque() { magick "$SRC" -resize "${1}x${1}" -background white -flatten -alpha off "$2"; echo "  $2 (${1}px)"; }
    alpha()  { magick "$SRC" -resize "${1}x${1}" "$2"; echo "  $2 (${1}px, alpha)"; }
    # padded opaque: scale logo to a fraction of the canvas, center on white (watch face needs buffer)
    padded() { local inner; inner=$(awk "BEGIN{printf \"%d\", $1*$3}"); \
               magick "$SRC" -resize "${inner}x${inner}" -background white -gravity center -extent "${1}x${1}" -alpha off "$2"; \
               echo "  $2 (${1}px, ${3}x buffer)"; }

    echo "🖼  Mac AppIcon:"
    for s in 16 32 64 128 256 512 1024; do
        opaque $s "MacApp/Assets.xcassets/AppIcon.appiconset/icon-$s.png"
    done
    echo "📱 iPhone AppIcon:"
    opaque 1024 "iPhoneApp/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    echo "⌚ Watch AppIcon (padded for circular face):"
    padded 1024 "WatchApp/Assets.xcassets/AppIcon.appiconset/icon-1024.png" 0.70
    echo "🖼  DeckLogo imageset (in-app, transparent):"
    alpha 80  "iPhoneApp/Assets.xcassets/DeckLogo.imageset/deck-logo.png"
    alpha 160 "iPhoneApp/Assets.xcassets/DeckLogo.imageset/deck-logo@2x.png"
    alpha 240 "iPhoneApp/Assets.xcassets/DeckLogo.imageset/deck-logo@3x.png"
    echo "🎨 Marketing logos:"
    alpha 1024 "public/logo/mac-logo.png"
    alpha 1024 "public/logo/ios-logo.png"
    echo "✅ Icons regenerated from $SRC"

# Build Mac menu bar app
build-mac:
    xcodebuild -scheme DeckMac build

# Build iOS app for physical device
build-ios:
    @if [ -z "${XCODE_DEVICE_ID:-}" ]; then \
        echo "Error: XCODE_DEVICE_ID not set. Create .env file with XCODE_DEVICE_ID=your-udid"; \
        exit 1; \
    fi
    xcodebuild -scheme DeckiOS -destination 'id={{ env("XCODE_DEVICE_ID", "") }}' build

# Build iOS app for simulator
build-sim:
    xcodebuild -scheme DeckiOS -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' build

# Build and run iOS app in simulator
run-sim: build-sim
    xcrun simctl boot "iPhone 16" 2>/dev/null || true
    xcrun simctl install booted "{{ ios_sim_app }}"
    xcrun simctl launch booted com.dou.clicker-ios

# Build and run Mac app
run-mac: build-mac
    #!/usr/bin/env bash
    set -euo pipefail
    # Resolve DerivedData at runtime (parse-time vars are empty on a fresh checkout)
    derived=$(ls -td ~/Library/Developer/Xcode/DerivedData/Deck-* 2>/dev/null | head -1)
    if [ -z "$derived" ]; then echo "❌ No Deck DerivedData folder found — did the build run?"; exit 1; fi
    open "$derived/Build/Products/Debug/Deck.app"

# Build (Release) and install Mac app into /Applications
install-mac: build-mac-release
    #!/usr/bin/env bash
    set -euo pipefail
    # Resolve DerivedData at runtime (parse-time vars are empty on a fresh checkout)
    derived=$(ls -td ~/Library/Developer/Xcode/DerivedData/Deck-* 2>/dev/null | head -1)
    if [ -z "$derived" ]; then echo "❌ No Deck DerivedData folder found — did the build run?"; exit 1; fi
    app="$derived/Build/Products/Release/Deck.app"
    if [ ! -d "$app" ]; then echo "❌ $app not found — did the build succeed?"; exit 1; fi
    echo "📦 Installing Deck.app → /Applications ..."
    # Quit any running instance so the bundle can be replaced cleanly
    osascript -e 'quit app "Deck"' 2>/dev/null || true
    rm -rf "/Applications/Deck.app"
    ditto "$app" "/Applications/Deck.app"
    echo "✅ Installed: /Applications/Deck.app"
    open "/Applications/Deck.app"

# Build and install iOS app on device
install-ios: build-ios
    @if [ -z "${DEVICECTL_ID:-}" ]; then \
        echo "Error: DEVICECTL_ID not set. Run 'xcrun devicectl list devices' to find your device UUID"; \
        exit 1; \
    fi
    xcrun devicectl device install app --device {{ env("DEVICECTL_ID", "") }} "{{ ios_app }}"

# Build, install, and launch iOS app on device
run-ios: install-ios
    xcrun devicectl device process launch --device {{ env("DEVICECTL_ID", "") }} com.dou.clicker-ios

# Build and deploy iPhone + Watch apps to physical devices
deploy: build-ios
    @echo "📱 Installing iPhone + Watch apps on device..."
    xcrun devicectl device install app --device {{ env("DEVICECTL_ID", "") }} "{{ ios_app }}"
    @echo ""
    @echo "✅ Deployed! Watch app will sync to your paired Apple Watch automatically."
    @echo "   If it doesn't appear, open the Watch app on iPhone → My Watch → Installed Apps"

# Uninstall iOS app from device (removes app + all data)
uninstall-ios:
    @if [ -z "${DEVICECTL_ID:-}" ]; then \
        echo "Error: DEVICECTL_ID not set. Run 'xcrun devicectl list devices' to find your device UUID"; \
        exit 1; \
    fi
    @echo "🗑️  Uninstalling Deck from device..."
    xcrun devicectl device uninstall app --device {{ env("DEVICECTL_ID", "") }} com.dou.clicker-ios || echo "App not installed or already removed"
    @echo "✅ App and all data removed"

# Complete clean reinstall: uninstall, clean build, install fresh
clean-install-ios: uninstall-ios clean build-ios install-ios
    @echo "✅ Fresh installation complete"

# Build and run iOS app in screenshot mode (no trial banner)
screenshot:
    xcodebuild -scheme DeckiOS \
        -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' \
        SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG SCREENSHOT_MODE' \
        build
    xcrun simctl boot "iPhone 16" 2>/dev/null || true
    xcrun simctl install booted "{{ ios_sim_app }}"
    xcrun simctl launch booted com.dou.clicker-ios

# Clean build artifacts
clean:
    xcodebuild -scheme DeckMac clean
    xcodebuild -scheme DeckiOS clean
    @echo "🧹 Cleaning up mounted volumes and installed app (requires sudo)..."
    -sudo umount -f /Volumes/Deck 2>/dev/null || true
    -sudo rm -rf /Volumes/Deck 2>/dev/null || true
    -sudo rm -rf /Applications/Deck.app 2>/dev/null || true
    @echo "✅ Clean complete"

# List connected iOS devices
list-devices:
    xcrun xctrace list devices

# ─────────────────────────────────────────────────────────────────────────────
# iOS App Store Distribution
# ─────────────────────────────────────────────────────────────────────────────

# Archive iOS app for App Store
archive-ios:
    xcodebuild archive \
        -scheme DeckiOS \
        -archivePath ./build/Deck.xcarchive \
        -destination 'generic/platform=iOS'

# Export and upload iOS app to App Store Connect
upload-ios:
    xcodebuild -exportArchive \
        -archivePath ./build/Deck.xcarchive \
        -exportPath ./build/export \
        -exportOptionsPlist ExportOptions.plist

# Archive and upload iOS app to App Store Connect
release-ios: archive-ios upload-ios

# ─────────────────────────────────────────────────────────────────────────────
# Mac GitHub Distribution (Signed + Notarized DMG)
# ─────────────────────────────────────────────────────────────────────────────

# Build Mac app in Release configuration
build-mac-release:
    xcodebuild -scheme DeckMac -configuration Release build

# Verify app is signed correctly for distribution
verify-signing: build-mac-release
    @echo "🔍 Verifying code signature..."
    codesign --verify --deep --strict --verbose=2 "{{ release_mac_app }}"
    @echo ""
    @echo "🔍 Checking signing identity..."
    codesign -dvv "{{ release_mac_app }}" 2>&1 | grep "Authority"
    @echo ""
    @echo "🔍 Checking Hardened Runtime..."
    codesign -dvv "{{ release_mac_app }}" 2>&1 | grep -E "(flags|runtime)"
    @echo ""
    @echo "✅ Signature verification complete"

# Create DMG for Mac app distribution (unsigned)
dmg: build-mac-release
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p ./build
    rm -f "./build/{{ dmg_name }}-{{ version }}.dmg"
    echo "Creating DMG with custom icon..."

    # Create iconset from PNG
    rm -rf ./build/dmg-icon.iconset
    mkdir -p ./build/dmg-icon.iconset
    sips -s format png -z 16 16     "{{ mac_logo }}" --out ./build/dmg-icon.iconset/icon_16x16.png
    sips -s format png -z 32 32     "{{ mac_logo }}" --out ./build/dmg-icon.iconset/icon_16x16@2x.png
    sips -s format png -z 32 32     "{{ mac_logo }}" --out ./build/dmg-icon.iconset/icon_32x32.png
    sips -s format png -z 64 64     "{{ mac_logo }}" --out ./build/dmg-icon.iconset/icon_32x32@2x.png
    sips -s format png -z 128 128   "{{ mac_logo }}" --out ./build/dmg-icon.iconset/icon_128x128.png
    sips -s format png -z 256 256   "{{ mac_logo }}" --out ./build/dmg-icon.iconset/icon_128x128@2x.png
    sips -s format png -z 256 256   "{{ mac_logo }}" --out ./build/dmg-icon.iconset/icon_256x256.png
    sips -s format png -z 512 512   "{{ mac_logo }}" --out ./build/dmg-icon.iconset/icon_256x256@2x.png
    sips -s format png -z 512 512   "{{ mac_logo }}" --out ./build/dmg-icon.iconset/icon_512x512.png
    sips -s format png -z 1024 1024 "{{ mac_logo }}" --out ./build/dmg-icon.iconset/icon_512x512@2x.png
    iconutil -c icns ./build/dmg-icon.iconset -o ./build/dmg-icon.icns

    # Create temp folder for DMG contents
    rm -rf ./build/dmg-temp
    mkdir -p ./build/dmg-temp
    cp -R "{{ release_mac_app }}" ./build/dmg-temp/
    ln -s /Applications ./build/dmg-temp/Applications

    # Create read-write DMG first
    hdiutil create -volname "{{ dmg_name }}" \
        -srcfolder ./build/dmg-temp \
        -ov -format UDRW \
        "./build/{{ dmg_name }}-rw.dmg"

    # Mount, set volume icon, unmount
    hdiutil attach "./build/{{ dmg_name }}-rw.dmg" -mountpoint "/Volumes/{{ dmg_name }}"
    cp ./build/dmg-icon.icns "/Volumes/{{ dmg_name }}/.VolumeIcon.icns"
    SetFile -a C "/Volumes/{{ dmg_name }}"
    hdiutil detach "/Volumes/{{ dmg_name }}"
    sleep 2

    # Convert to compressed read-only DMG
    hdiutil convert "./build/{{ dmg_name }}-rw.dmg" \
        -format UDZO \
        -o "./build/{{ dmg_name }}-{{ version }}.dmg"

    # Cleanup
    rm -rf ./build/dmg-temp ./build/dmg-icon.iconset ./build/dmg-icon.icns "./build/{{ dmg_name }}-rw.dmg"
    echo "✅ DMG created: ./build/{{ dmg_name }}-{{ version }}.dmg"

# Sign the DMG with Developer ID
sign-dmg: dmg
    @echo "🔏 Signing DMG..."
    codesign --force --sign "{{ signing_identity }}" "./build/{{ dmg_name }}-{{ version }}.dmg"
    @echo "✅ DMG signed"

# Submit DMG for notarization and wait for result
notarize: sign-dmg
    @echo "📤 Submitting for notarization..."
    xcrun notarytool submit "./build/{{ dmg_name }}-{{ version }}.dmg" \
        --keychain-profile {{ notary_profile }} \
        --wait
    @echo ""
    @echo "📎 Stapling notarization ticket..."
    xcrun stapler staple "./build/{{ dmg_name }}-{{ version }}.dmg"
    @echo ""
    @echo "✅ Notarization complete!"

# Verify the DMG is properly notarized
verify-notarization:
    @echo "🔍 Verifying notarization..."
    spctl --assess --type open --context context:primary-signature --verbose=2 "./build/{{ dmg_name }}-{{ version }}.dmg"
    @echo ""
    xcrun stapler validate "./build/{{ dmg_name }}-{{ version }}.dmg"
    @echo "✅ Notarization verified"

# Build, sign, notarize DMG and show GitHub release instructions
release-mac: notarize
    @echo ""
    @echo "📦 Mac DMG ready for GitHub release!"
    @echo "   File: ./build/{{ dmg_name }}-{{ version }}.dmg"
    @echo ""
    @echo "To create a GitHub release:"
    @echo "  gh release create v{{ version }} ./build/{{ dmg_name }}-{{ version }}.dmg \\"
    @echo "    --title 'Deck v{{ version }}' \\"
    @echo "    --notes 'Release notes here'"
    @echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Notarization Setup
# ─────────────────────────────────────────────────────────────────────────────

# Check if Developer ID certificate is installed
check-signing:
    @echo "🔍 Looking for Developer ID Application certificate..."
    @security find-identity -v -p codesigning | grep "Developer ID Application" || \
        (echo "❌ No Developer ID Application certificate found!" && \
         echo "" && \
         echo "To create one:" && \
         echo "  1. Go to https://developer.apple.com/account/resources/certificates/list" && \
         echo "  2. Click + and select 'Developer ID Application'" && \
         echo "  3. Follow the prompts to create and download" && \
         echo "  4. Double-click the .cer file to install" && \
         exit 1)
    @echo "✅ Developer ID certificate found"

# Store notarization credentials in keychain (interactive)
setup-notary:
    @echo "📝 Setting up notarization credentials..."
    @echo "You'll need:"
    @echo "  - Your Apple ID email"
    @echo "  - Team ID: HD35YQ72U4"
    @echo "  - An app-specific password from https://appleid.apple.com"
    @echo ""
    xcrun notarytool store-credentials {{ notary_profile }} --team-id HD35YQ72U4

# Show the log from the last notarization submission
notary-log:
    @echo "📋 Recent notarization submissions:"
    xcrun notarytool history --keychain-profile {{ notary_profile }}

# ─────────────────────────────────────────────────────────────────────────────
# Homebrew Tap
# ─────────────────────────────────────────────────────────────────────────────

# Refresh the deck cask in the shared douinc tap (github.com/douinc/homebrew-tap) after a release.
# The deck cask lives alongside clicker-remote-receiver in that repo; this triggers the tap's
# update-deck-cask workflow, which downloads the published DMG and recomputes the sha256.
# Requires the GitHub release (Deck-{{ version }}.dmg) to exist first, and `gh` auth with
# workflow access to douinc/homebrew-tap.
update-tap:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🍺 Dispatching homebrew-tap to update deck → v{{ version }} ..."
    gh workflow run update-deck-cask.yml -R douinc/homebrew-tap -f version="{{ version }}"
    echo "✅ Dispatched. Watch the run:  gh run watch -R douinc/homebrew-tap"
    echo "   Install: brew tap douinc/tap && brew install --cask deck"
