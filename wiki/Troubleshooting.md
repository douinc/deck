# Troubleshooting

Common issues and their solutions.

## Connection Issues

### Mac not appearing on iPhone

**Symptoms**: iPhone doesn't see the Mac in the device list

**Solutions**:

1. **Same Network**: Ensure both devices are on the same WiFi network
2. **Restart Apps**: Quit and relaunch both apps
3. **Check Firewall**: Disable macOS firewall temporarily to test
4. **Bonjour Services**: Verify Info.plist has correct Bonjour entries:
   ```xml
   <key>NSBonjourServices</key>
   <array>
       <string>_clickerremote._tcp</string>
       <string>_clickerremote._udp</string>
   </array>
   ```

### Connection Drops Frequently

**Solutions**:

1. **Disable VPN**: VPNs can interfere with local network discovery
2. **Check WiFi**: Ensure stable WiFi connection on both devices
3. **Bluetooth**: Try connecting via Bluetooth instead (move devices closer)

## Keystroke Issues

### Keystrokes Not Working

**Symptoms**: Connected successfully but slides don't change

**Solutions**:

1. **Grant Accessibility Permission**:
   - Go to System Settings → Privacy & Security → Accessibility
   - Find and enable Deck
   - **Restart the app**: Click the menu bar icon → Debug → Restart App
   - If already enabled, toggle off and on, then restart

2. **Check Frontmost App**: Ensure your presentation app (Keynote, PowerPoint) is in focus

3. **Test with TextEdit**: Open TextEdit and try — you should see left/right arrow behavior

### Wrong Key Actions

**Symptoms**: Slides skip or behave unexpectedly

**Solutions**:

- Different presentation apps may use different keys
- Deck sends Right/Left arrow keys
- Most apps: Right = Next, Left = Previous
- Some apps may be configured differently

## Build Issues

### "Signing requires development team"

**Solution**:

1. Open `project.yml`
2. Find `DEVELOPMENT_TEAM: HD35YQ72U4`
3. Replace with your Team ID
4. Run `xcodegen generate`

Find your Team ID:
```bash
security find-identity -v -p codesigning
```

### Notarization Fails

**Check the log**:
```bash
just notary-log
# Then view specific submission:
xcrun notarytool log <submission-id> --keychain-profile notarytool-profile
```

**Common Causes**:

| Error | Fix |
|-------|-----|
| Wrong certificate | Use "Developer ID Application", not "Apple Distribution" |
| Missing timestamp | Ensure `--timestamp` flag in signing |
| Debug entitlement | Build Release config, not Debug |

**Verify Settings in project.yml**:
```yaml
configs:
  Release:
    CODE_SIGN_STYLE: Manual
    CODE_SIGN_IDENTITY: "Developer ID Application"
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO
    OTHER_CODE_SIGN_FLAGS: "--timestamp"
```

### "Unable to find destination"

**Solution**: Specify OS version explicitly:

```bash
xcodebuild -scheme DeckiOS \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' \
  build
```

List available destinations:
```bash
xcodebuild -scheme DeckiOS -showdestinations
```

### MultipeerConnectivity Not Working

**Symptoms**: Apps build but can't discover each other

**Solution**: Verify `project.yml` has network permissions in `info.properties`:

```yaml
info:
  properties:
    NSBonjourServices:
      - _clickerremote._tcp
      - _clickerremote._udp
    NSLocalNetworkUsageDescription: "..."
```

Keys must be in `info.properties`, not just the source Info.plist files.

## Apple Watch Issues

### Watch Not Connecting

**Symptoms**: Watch app shows "Disconnected", commands don't work

**Solutions**:

1. **iPhone app must be running**: The Watch connects through the iPhone, not directly to the Mac
2. **Check iPhone connection**: The iPhone must be connected to the Mac first
3. **Relaunch Watch app**: Force-quit and reopen on the Watch
4. **Check WCSession**: Ensure the Watch is paired and the Watch app is installed

### Watch Commands Not Reaching Mac

**Symptoms**: Watch shows "Connected" but slides don't change

**Solutions**:

1. **iPhone screen locked**: The iPhone disables auto-lock while connected, but if you manually lock it, the MultipeerConnectivity session drops. Unlock the iPhone to restore the connection
2. **iPhone app in background**: Bring the Deck app to the foreground on the iPhone
3. **Retry mechanism**: The Watch retries commands up to 3 times — wait a moment and try again

### Watch Timer Reset Not Working

**Solution**: Long press (not tap) the timer display. You should feel a strong haptic pulse confirming the reset.

### Wrist Flick Only Goes Forward / Previous Not Working

**Check "No Going Back" setting**: Open Watch Settings → ensure "No Going Back" is toggled off. When enabled, backward flick gestures are intentionally ignored and the previous-slide button is dimmed.

### Wrist Flick Triggers Wrong Direction

**Check "Invert Gestures" setting**: Open Watch Settings → toggle "Invert Gestures" to swap the forward/backward flick mapping. The footer text shows the current mapping (Clockwise → Next or Counterclockwise → Next).

---

## SwiftUI Issues

### Section Syntax Error

**Wrong**:
```swift
Section("Header") {
    // content
} footer: {
    Text("Footer")
}
```

**Correct**:
```swift
Section {
    // content
} header: {
    Text("Header")
} footer: {
    Text("Footer")
}
```

## Subscription Issues

### Trial Not Starting

**Symptoms**: App immediately shows paywall

**Solutions**:

1. Delete app and reinstall (trial is Keychain-stored)
2. Check device date is correct
3. Reset Keychain entry (development only):
   ```swift
   // Delete: com.dou.deck.trial.start from Keychain
   ```

### Purchases Not Restoring

**Solutions**:

1. Tap "Restore Purchases" in paywall
2. Ensure signed in with correct Apple ID
3. Check App Store Connect for transaction status

## Debugging Commands

### Check Built Info.plist

```bash
find ~/Library/Developer/Xcode/DerivedData/Deck-*/Build/Products \
  -name "Info.plist" -exec plutil -p {} \;
```

### List Schemes

```bash
xcodebuild -project Deck.xcodeproj -list
```

### List Connected Devices

```bash
xcrun devicectl list devices
```

### List Simulators

```bash
xcrun simctl list devices available
```

### Check Code Signature

```bash
codesign -dv --verbose=4 /path/to/app
```

## Still Stuck?

- Search [GitHub Issues](https://github.com/douinc/deck/issues)
- Open a new issue with:
  - macOS/iOS version
  - Xcode version
  - Steps to reproduce
  - Error messages or logs
