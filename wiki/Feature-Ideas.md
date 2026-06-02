# Feature Ideas

A brainstorm of potential new features for the Deck presentation remote system. Ideas are organized by category with rough complexity estimates.

> **Legend**: 🟢 Low complexity · 🟡 Medium complexity · 🔴 High complexity

---

## Navigation & Slide Control

### Custom Key Mappings 🟡
Let users configure which keystrokes are sent for each command on a per-app basis. Keynote, PowerPoint, and Google Slides all use different shortcuts (e.g., PowerPoint uses `N`/`P` for next/previous while Keynote uses arrow keys). The Mac app could detect the frontmost app and switch mappings automatically, or let users define custom profiles.

### Slide Counter 🟡
The Mac app sends the current slide number back to the iPhone and Watch. This requires the Mac to read slide position from the presentation app (likely via Accessibility API or AppleScript). Displays as a simple "Slide 12 / 34" indicator on the remote.

### Slide Bookmarks / Jump-to-Slide 🟡
Bookmark key slides (e.g., "Q&A", "Demo", "Backup slides") and jump directly to them from iPhone. Could work by sending a rapid sequence of keystrokes or by integrating with AppleScript to set the slide index directly.

### Auto-Advance Mode 🟢
Timer-based automatic slide progression with configurable per-slide intervals. Useful for lightning talks, Pecha Kucha (20 slides x 20 seconds), or kiosk displays. Haptic countdown before each advance.

### Laser Pointer Mode 🔴
Use the iPhone's gyroscope and accelerometer to move a virtual cursor overlay on the Mac screen. The iPhone tracks device orientation relative to a calibration point and sends continuous position updates. Mac renders a colored dot overlay on top of all windows.

---

## Timer & Pacing

### Per-Slide Timing 🟡
Track how long you spend on each slide during a presentation. After the session, view a breakdown showing time per slide. Helps identify slides where you tend to linger or rush.

### Rehearsal Mode 🟡
Set target durations for each slide or section. During rehearsal, the timer shows a progress bar for the current slide's budget. Haptic and visual alerts when you're over time, with a running deficit/surplus indicator.

### Pace Coach 🟡
Gentle haptic nudges if you're spending too long on one slide relative to your overall time budget. Configurable sensitivity — from subtle reminders to urgent buzzes. Works on both iPhone and Watch.

### Stage Display Mode 🟢
Large, high-contrast timer optimized for visibility from across the stage. iPhone in landscape orientation with massive countdown digits, elapsed time, and color-coded status (green → yellow → red as time runs out). Useful when you place your phone on the podium.

---

## Connectivity & Multi-Device

### Multi-Mac Support 🔴
Connect to and control multiple Macs simultaneously. Use case: a presenter with a main projector and a confidence monitor on separate machines, or a classroom with multiple screens. The iPhone shows a list of connected Macs and can send commands to all or individually.

### Multi-Presenter Mode 🟡
Allow multiple iPhones to connect to the same Mac. Useful for co-presentations where different speakers control slides from their own device. Optional: a "presenter token" that designates who has active control, passed between speakers with a tap.

### Connection Quality Indicator 🟢
Show signal strength or round-trip latency on the iPhone and Watch. A simple colored dot (green/yellow/red) based on ping response time. Helps presenters know if they're walking too far from the Mac.

### QR Code Pairing 🟡
The Mac app displays a QR code containing its peer ID or a pairing token. Scan it with the iPhone camera to instantly connect instead of browsing/waiting for discovery. Faster and more reliable in venues with many devices on the network.

### Direct Bluetooth HID Mode 🔴
iPhone acts as a Bluetooth keyboard directly, sending keystrokes without needing the Mac app installed at all. Useful for presenting on someone else's computer or a conference-provided machine. Uses CoreBluetooth HID profile.

---

## Apple Ecosystem Integration

### Live Activities 🟡
Show the current slide number, elapsed time, and timer status on the iPhone Lock Screen and Dynamic Island while presenting. Lets you glance at progress without unlocking or opening the app. Updates in real-time using ActivityKit push updates.

### Home Screen Widgets 🟡
Glanceable widgets for iPhone and Watch:
- **iPhone**: Quick-connect widget showing connection status with tap-to-connect, or a timer widget.
- **Watch**: Complication showing connection status or current slide number on the watch face.

### Siri & Shortcuts Integration 🟡
"Hey Siri, next slide" — voice control for hands-free operation. Also expose actions to the Shortcuts app so users can build automations: trigger a Shortcut when the presentation starts, send a notification when time is up, or log presentation data to a spreadsheet.

### SharePlay Support 🔴
Remote participants on a FaceTime call can see real-time slide position synced through SharePlay. The presenter's iPhone broadcasts slide changes, and remote viewers' devices stay in sync. Could pair with screen sharing for a complete remote presentation experience.

### Handoff 🟡
Start controlling the presentation from iPhone, raise your wrist, and seamlessly continue on Watch — or vice versa. Uses NSUserActivity to transfer the active session context between devices. Timer state and connection persist across the handoff.

### Focus Mode Integration 🟢
Automatically enable a "Presenting" Focus filter when connected to a Mac. Silences notifications, hides sensitive content, and optionally sets a custom Lock Screen. Deactivates when the presentation session ends.

---

## Presenter Experience

### Presenter Notes Display 🔴
The Mac reads presenter notes from the current slide (via AppleScript for Keynote/PowerPoint or Accessibility API) and sends them back to the iPhone. The remote shows scrollable notes below the control buttons. Requires per-app integration but transforms the iPhone into a full confidence monitor.

### Audience Q&A 🔴
Generate a QR code linking to a simple web page (could be a local web server on the Mac or a cloud service) where audience members submit questions. Questions stream to the iPhone in real-time, and the presenter can mark them as answered or star them for later.

### Slide Preview Thumbnails 🔴
See the current and next slide as small thumbnail images on the iPhone. Requires the Mac to capture or extract slide images and stream them over MultipeerConnectivity. Bandwidth-intensive but transformative for the presenting experience.

### Custom Screen Messages 🟡
Beyond just black screen, support white screen and custom overlay messages ("Back in 5 minutes", "Questions?", "Thank you!"). Configurable preset messages that the Mac renders as a full-screen overlay. Triggered from the iPhone with a quick-action menu.

---

## Analytics & History

### Presentation Analytics 🟡
Post-presentation summary showing: total duration, number of slides advanced, average time per slide, a timeline chart of slide changes, and pacing analysis. Stored locally on iPhone with option to export.

### Session History 🟢
Log past presentations with date, duration, slide count, and which Mac was used. Browse history in a list view. Useful for tracking speaking engagements or rehearsal progress over time.

### Export Timer Data 🟢
Share presentation timing data as CSV, JSON, or to Apple Health (as a "mindfulness" session with duration). Integration with Shortcuts for automatic logging to spreadsheets or note-taking apps.

---

## Accessibility & Customization

### VoiceOver Optimization 🟢
Audit and enhance all controls with meaningful accessibility labels, hints, and traits. Ensure the full presentation flow works with VoiceOver enabled — critical for visually impaired presenters.

### Customizable Button Layout 🟡
Let users rearrange, resize, or hide buttons on the iPhone remote. Some presenters only need next/previous; others want all controls visible. Support for custom button pages or a minimal mode.

### Theming Options 🟢
Allow light mode for bright environments or custom accent colors beyond the current dark-only design. Per-user preference with quick toggle. Keep dark mode as default since it's optimized for stage visibility.

### Configurable Haptic Patterns 🟡
Let users create custom vibration patterns for different events: slide advance, timer milestones, connection lost. Different intensity levels and rhythms to convey information without looking at the screen.

---

## Watch-Specific

### Watch Face Complication 🟡
Show connection status, current slide number, or elapsed time directly on the watch face. Supports multiple complication families (circular, rectangular, inline). Tap to launch the app.

### Smart Stack Widget 🟢
A widget in the watchOS Smart Stack showing timer and connection status at a glance. Automatically surfaces when a presentation is detected (using relevance scoring).

### Digital Crown Control 🟡
Use the Digital Crown rotation to scroll through slides — rotate forward for next, backward for previous. Provides a tactile, precise alternative to wrist gestures or button taps. Configurable sensitivity and detent mapping.

### ~~Forward-Only Flick Mode~~ ✅ Implemented
~~Disable backward flick gestures so only forward flicks are recognized, reducing accidental triggers during presentations.~~ Shipped as the "No Going Back" toggle in Watch flick mode settings.

### Expanded Double-Tap Gestures 🟢
Build on the existing watchOS 11 `handGestureShortcut` support. Map double-tap to configurable actions: next slide, previous slide, or start/stop timer. Let users choose what double-tap does in settings.

---

## Infrastructure & Developer Experience

### End-to-End Encryption 🟡
Encrypt command traffic between devices using a shared key established during pairing. Currently MultipeerConnectivity uses optional encryption — upgrade to required with a custom key exchange for sensitive corporate presentations.

### Plugin / Extension System 🔴
Allow third-party developers to create plugins that add new commands, integrations, or UI panels. For example, a plugin that integrates with OBS for streaming, or one that controls Zoom's screen share. Uses a defined command protocol and Swift Package plugins.

### Automated UI Testing 🟡
XCUITest suites for all three apps covering the core flows: onboarding, connection, slide control, timer, and settings. Run in CI on simulators to catch regressions.

---

*Have an idea? Open an issue or submit a PR!*
