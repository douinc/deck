# Feature Ideas

What has shipped from this list, and what could come next. Ideas carry a rough complexity estimate.

> **Legend**: 🟢 Low complexity · 🟡 Medium complexity · 🔴 High complexity

---

## Shipped

| Idea | Shipped as |
|------|------------|
| Laser Pointer Mode | The pointer: hold a button and aim the iPhone to move the Mac's cursor, tap to click. Spotlight dims the Mac's screen around the cursor. |
| Customizable Button Layout | Arrange Buttons: touch and hold, then drag any control. Layouts mirror with the holding hand. |
| Left-handed layout | Holding Hand setting |
| Click to advance | Next Button Left-Clicks setting |
| Live Activities | Timer on the Lock Screen and in the Dynamic Island |
| Digital Crown Control | One Crown detent per slide, with Invert Crown |
| Forward-Only Flick Mode | "No Going Back" in Wrist Flick mode |
| QR Code Pairing (partly) | The Mac setup guide shows a QR code for the App Store. It does not pair devices. |
| VoiceOver labels | Every remote control has an accessibility label; the pointer has a hint |

---

## Navigation & Slide Control

### Start, End and Black Screen buttons 🟢
The Mac already understands `start` (Return), `end` (Escape) and `black` (B). The remote has no buttons for them. Add them as optional controls that can be dragged onto the arcs.

### Custom Key Mappings 🟡
Let users choose which keystrokes each command sends, per app. The Mac app could detect the frontmost app and switch mappings automatically, or let users define profiles.

### Slide Counter 🟡
The Mac sends the current slide number back to the iPhone and Watch. Requires reading slide position from the presentation app through the Accessibility API or AppleScript. Shows as "Slide 12 / 34".

### Slide Bookmarks / Jump-to-Slide 🟡
Bookmark key slides ("Q&A", "Demo", "Backup") and jump to them from the iPhone, by a keystroke sequence or by setting the slide index through AppleScript.

### Auto-Advance Mode 🟢
Timer-based slide progression with a configurable interval. Useful for lightning talks, Pecha Kucha (20 slides × 20 seconds) or kiosk displays. Haptic countdown before each advance.

### Pointer Extras 🟡
Build on the pointer: a drawn laser dot instead of the system cursor, a choice of spotlight size and dim level, drag and scroll gestures, and a recenter gesture.

---

## Timer & Pacing

### Longer Limits 🟢
The timer arc tops out at 30 minutes. Add a longer scale, or a second turn of the arc, for lectures and workshops.

### Per-Slide Timing 🟡
Track how long each slide stays up. After the session, show a breakdown to reveal where you linger or rush.

### Rehearsal Mode 🟡
Set target durations per slide or section. During rehearsal, show the current slide's budget with a running deficit or surplus.

### Pace Coach 🟡
Haptic nudges when you spend too long on one slide relative to the overall budget, on iPhone and Watch.

### Stage Display Mode 🟢
A large, high-contrast landscape timer for a phone resting on the podium.

### Shared Watch Timer 🟡
The watch timer is separate from the iPhone's. Sync them so the watch shows the same countdown, limit and colors.

---

## Connectivity & Multi-Device

### Multi-Mac Support 🔴
Control more than one Mac at once, for a main projector and a confidence monitor on separate machines.

### Multi-Presenter Mode 🟡
Several iPhones on one Mac, with a "presenter token" passed between speakers.

### Connection Quality Indicator 🟢
A colored dot on iPhone and Watch based on keepalive round-trip time, so presenters know when they have walked too far from the Mac.

### Tap-to-Pair 🟡
A QR code or NFC tag from the Mac that connects a specific iPhone directly, skipping the device list. Faster in venues with many Macs running Deck.

### Direct Bluetooth HID Mode 🔴
The iPhone acts as a Bluetooth keyboard, with no Mac app. Useful on someone else's computer.

### Windows and Linux Receivers 🔴
A receiver for non-Mac computers. MultipeerConnectivity is Apple-only, so this needs a second transport.

---

## Apple Ecosystem Integration

### Home Screen Widgets 🟡
A quick-connect or timer widget on iPhone, and a complication on the watch face showing connection status.

### Siri & Shortcuts Integration 🟡
"Next slide" by voice, plus Shortcuts actions for automations when a presentation starts or time runs out.

### SharePlay Support 🔴
Remote participants on a FaceTime call see slide position in sync.

### Handoff 🟡
Start on iPhone, continue on Watch, with timer state carried across.

### Focus Mode Integration 🟢
Turn on a "Presenting" Focus filter when connected to a Mac.

### iPad Support 🟡
The iPhone app is iPhone-only and portrait-only. An iPad layout could add room for notes.

---

## Presenter Experience

### Presenter Notes Display 🔴
The Mac reads the current slide's notes (AppleScript for Keynote and PowerPoint) and sends them to the iPhone.

### Slide Preview Thumbnails 🔴
Current and next slide as thumbnails on the iPhone, streamed from the Mac.

### Audience Q&A 🔴
A QR code linking to a page where the audience submits questions, streamed to the iPhone.

### Custom Screen Messages 🟡
White screen and overlay messages ("Back in 5 minutes", "Questions?") rendered by the Mac. The Spotlight overlay already shows how to draw above a full-screen slideshow.

---

## Analytics & History

### Presentation Analytics 🟡
A post-talk summary: duration, slides advanced, time per slide, pacing. Stored on the iPhone only.

### Session History 🟢
A log of past talks with date, duration and Mac name.

### Export Timer Data 🟢
Share timing data as CSV or JSON, or through Shortcuts.

---

## Accessibility & Customization

### VoiceOver Audit 🟢
Labels exist. Audit the full flow with VoiceOver on, including arranging buttons and setting the time limit on the arc, which are gesture-only today.

### Resize and Hide Buttons 🟡
Arrange Buttons moves controls. Add resizing, hiding ones you never use, and saved layouts per talk.

### Theming Options 🟢
Light mode for bright rooms, or custom accent colors. Dark stays the default for stage visibility.

### Configurable Haptic Patterns 🟡
Custom patterns and intensities for interval, halfway, time's up and overtime.

### Localization 🟡
The apps are English-only. Start with the setup and troubleshooting text, where clarity matters most.

---

## Watch-Specific

### Watch Face Complication 🟡
Connection status or elapsed time on the watch face. Tap to launch.

### Smart Stack Widget 🟢
Timer and connection status in the Smart Stack.

### Configurable Double Tap 🟢
Let users choose what double tap does: next slide, previous slide, or start and stop the timer.

### Flick Sensitivity 🟢
The flick threshold is fixed at 3.0 rad/s. Offer a sensitivity setting.

---

## Infrastructure & Developer Experience

### End-to-End Encryption 🟡
Sessions use optional MultipeerConnectivity encryption because required encryption proved less reliable on real networks. Add pairing with a shared key for corporate settings.

### Automated UI Testing 🟡
XCUITest suites for onboarding, connection, slide control, timer and settings, run in CI on simulators. There are no automated tests today.

### In-App Mac Updates 🟡
The Mac app only links to the release page. Adopt Sparkle or a similar updater.

### Plugin / Extension System 🔴
Third-party commands and integrations, such as OBS or Zoom control.

---

*Have an idea? [Open an issue](https://github.com/douinc/deck/issues) or submit a pull request.*
