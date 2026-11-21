# Troubleshooting

Problems and fixes, for people using Deck first and for developers after. The short version for users is on the [support page](https://deck.dou.so/support).

## Connection

### The iPhone can't find the Mac

The Mac advertises as soon as Deck launches, whether or not Accessibility is allowed or the setup guide is finished. The iPhone restarts its search every time it returns to the foreground and every 12 seconds while no Mac is visible. After about 10 seconds with nothing found it shows a checklist.

Work through these in order:

1. **Deck is open on the Mac.** Look for the Deck icon in the menu bar and click it. It should say "Waiting for your iPhone…". If it says "Deck is paused", choose **Resume Deck**.
2. **Local Network on the iPhone.** Settings → Deck → Local Network must be on. When it is off, the app shows "Deck can't look for your Mac" with an **Open Settings** button.
3. **Local Network on the Mac (macOS 15 or later).** System Settings → Privacy & Security → Local Network → turn on Deck. When it is off, the Mac's menu shows "Your iPhone can't find this Mac" with a Fix item.
4. **Same network.** Both devices must be on the same Wi‑Fi. Hotel, school, office and guest networks often isolate devices from each other. Turn on Personal Hotspot on the iPhone and join it from the Mac.
5. **VPN off.** A VPN on either device can hide them from each other.
6. **Firewall.** If the macOS firewall is set to block all incoming connections, allow Deck or turn that option off.
7. **Restart both apps.** On the Mac: Deck icon → Quit Deck, then open it again.

### "Couldn't connect" after tapping the Mac

The Mac was found but did not answer the invitation within 15 seconds.

1. Look at the Mac. If it is asking to let Deck find devices on your network, click **Allow**.
2. On the Mac: System Settings → Privacy & Security → Local Network → turn on Deck.
3. Quit and reopen Deck on the Mac, then tap **Try Again** on the iPhone.

### The connection drops

Deck notices a dead link within about 15 seconds and reconnects to the same Mac on its own, backing off from 1 to 8 seconds between attempts.

- **The Mac went to sleep.** Deck restarts its advertiser on wake; the iPhone reconnects when it sees the Mac again.
- **The iPhone was locked or Deck left the foreground.** iOS suspends the app and the session ends. Open Deck again. The screen stays awake by itself while the remote is showing.
- **Weak or crowded Wi‑Fi.** Use the iPhone's Personal Hotspot.
- **VPN.** Turn it off on both devices.

### Sending diagnostics

On the iPhone: **Help → Connection Diagnostics** shows session state and a log, with a button to copy it. On the Mac: Settings → **Show Debug Menu**, then Deck icon → Debug → **Copy Debug Info**. Include both when you [contact support](mailto:team@dou.so).

## Slide control

### Connected, but slides don't change

1. **Accessibility.** Click the Deck icon in the Mac menu bar. If it says "Deck can't change slides yet", click **Fix: Allow Deck in System Settings…** and turn on Deck under Privacy & Security → Accessibility. Deck relaunches itself when the switch goes on.
2. **Already on but still not working?** Turn the switch off and on again, or remove Deck from the Accessibility list with the minus button and add it back. Then quit and reopen Deck.
3. **Bring the slideshow to the front.** Deck sends keys to the frontmost app. Click the slideshow once.
4. **Check the menu.** With the iPhone connected, the Mac's menu shows "Last: Next slide ▶" when a command arrives. If that line updates and the slides don't move, the problem is Accessibility or focus. If it doesn't update, the problem is the connection.

### Next does nothing in one particular app

Deck sends the right arrow key for Next and the left arrow key for Previous. If the app advances on click instead, turn on **Next Button Left-Clicks** in the iPhone's settings and leave the Mac's cursor over the slides.

### Slides advance twice

Something else is also sending input: a second remote, a hardware clicker, or a watch gesture firing along with a tap. On the watch, turn on **Gesture Lock** in Wrist Flick mode or switch to Double Tap mode.

## Pointer

### The cursor doesn't move

- The pointer needs the same Accessibility permission as slide control. See above.
- The pointer needs Deck 2.0 or later on the Mac. An older Mac app ignores pointer messages while slides still work. Update with `brew upgrade --cask deck` or download the latest DMG.
- Hold the button. A press shorter than about a fifth of a second is a click, not a move.

### The cursor moves too fast or too slow

Change **Pointer Speed** in the iPhone's settings.

### The Mac's screen stays dimmed

Spotlight lifts when you release the pointer button, and by itself about 2 seconds after the Mac stops hearing from the iPhone. If it remains, quit and reopen Deck on the Mac.

### No dimming when I hold the pointer

Turn on **Spotlight** in the iPhone's settings under Pointer. It is off by default.

## Timer

### I can't change the time limit

The timer arc is locked while the timer runs. Pause it, then slide along the arc, or pick a preset under Duration in Settings.

### I can't rearrange the buttons

Arranging is also locked while the timer runs. Pause the timer, then touch and hold any button except the pointer.

### No buzzes

Check **Haptic Alerts** in Settings and use **Test Haptic**. Buzzes only fire while the timer is running.

### The timer isn't on the Lock Screen

Live Activities must be allowed: Settings → Deck → Live Activities. The activity starts when the iPhone connects to a Mac and ends when it disconnects.

## Apple Watch

### The watch shows "Connect your iPhone first" or "Disconnected"

The watch reaches the Mac through the iPhone.

1. Open Deck on the iPhone and connect to the Mac.
2. Keep Deck in the foreground on the iPhone.
3. Return to the watch. The controls appear by themselves.

### The watch says Connected, but slides don't change

- The iPhone was locked or Deck was sent to the background. Open Deck on the iPhone again.
- The watch retries a command up to 3 times over 1.5 seconds. Wait a moment and try again.

### Double tap does nothing

- Double tap needs Apple Watch Series 9 or later, or Ultra 2, running watchOS 11 or later.
- The display must be awake. Double tap does not work with your wrist down.
- In Wrist Flick mode, double tap turns flick detection on and off instead of changing slides.
- Check that Double Tap is turned on in the watch's Settings → Gestures.

### Wrist flick only goes forward

**No Going Back** is on. Turn it off in the watch app's settings. While it is on, the Previous button is dimmed too.

### Wrist flick goes the wrong way

Toggle **Invert Gestures**. The footer under the switch shows the current mapping.

### Wrist flicks do nothing

Flick detection must be on: the hand icon between the two buttons is yellow when it is. Tap it, or turn on **Auto-toggle with Wrist**. With **Gesture Lock** on, flicks are ignored for 3 seconds after each one.

### The Crown goes the wrong way

Toggle **Invert Crown** in the watch app's settings.

### The watch timer won't reset

Press and hold the time. A tap only starts or pauses it.

## Subscription

### The paywall appears right away

The 7-day trial starts the first time Deck opens on a device and is stored in the Keychain, so deleting and reinstalling does not restart it.

### I subscribed but still see the paywall

Tap **Restore Purchases** on the paywall and check that the iPhone is signed in to the Apple Account that bought the subscription.

### Cancel or manage

iPhone Settings → your name → Subscriptions → Deck.

## Mac app

### Update

`brew upgrade --cask deck`, or download the latest DMG. The menu shows "Update Available" when a newer release exists.

### Homebrew says the tap is untrusted

Run `brew trust douinc/tap` once, then install again. If you used the old tap, run `brew untap douinc/deck` and `brew tap douinc/tap`.

### Uninstall

Quit Deck, then `brew uninstall --cask deck` or drag Deck from Applications to the Trash. Remove Deck from System Settings → Privacy & Security → Accessibility.

---

## Development

### "Signing requires development team"

Replace `HD35YQ72U4` with your Team ID in `project.yml`, then run `just generate`.

```bash
security find-identity -v -p codesigning
```

### Apps build but can't discover each other

Info.plist keys must be in `info.properties` in `project.yml`, not only in the plist files, because XcodeGen rewrites them:

```yaml
info:
  properties:
    NSBonjourServices:
      - _clickerremote._tcp
      - _clickerremote._udp
    NSLocalNetworkUsageDescription: "..."
```

Check what was built:

```bash
find ~/Library/Developer/Xcode/DerivedData/Deck-*/Build/Products \
  -name "Info.plist" -exec plutil -p {} \;
```

### Accessibility stops working after every rebuild

macOS ties the permission to the code signature. Remove Deck from the Accessibility list and add the newly built app, or reset it:

```bash
tccutil reset Accessibility com.dou.clicker-mac
```

### "Unable to find destination"

```bash
xcodebuild -scheme DeckiOS -showdestinations
xcrun simctl list devices available
```

The justfile targets `iPhone 16, OS=18.2`. Change the destination if that simulator is not installed.

### Version numbers reset

`just generate` rewrites the Info.plist files from `project.yml`. Set versions there.

### Resetting the trial

The trial start date is a generic-password Keychain item with the account `com.dou.clicker-ios.trialStartDate`. Deleting the app does not remove it. On a simulator, erase the device:

```bash
xcrun simctl erase "iPhone 16"
```

`just screenshot` builds with `SCREENSHOT_MODE`, which skips the trial entirely.

### Notarization fails

```bash
just notary-log
xcrun notarytool log <submission-id> --keychain-profile notarytool-profile
```

| Error | Fix |
|-------|-----|
| Wrong certificate | Use "Developer ID Application", not "Apple Distribution" |
| Missing timestamp | Keep `OTHER_CODE_SIGN_FLAGS: "--timestamp"` |
| Debug entitlement | Build Release, with `CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO` |

### Useful commands

```bash
xcodebuild -project Deck.xcodeproj -list      # Schemes
xcrun devicectl list devices                  # Connected devices
codesign -dv --verbose=4 /path/to/Deck.app    # Signature details
```

## Still stuck?

- Email [team@dou.so](mailto:team@dou.so)
- Search or open a [GitHub issue](https://github.com/douinc/deck/issues) with your macOS, iOS and Deck versions, what you did, and the diagnostics from both apps
