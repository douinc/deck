# API Reference

This reference documents the key classes and protocols in the codebase.

## Shared Code

### RemoteCommand

The command protocol between iPhone and Mac:

```swift
// Shared/RemoteCommand.swift
enum RemoteCommand: String, Codable {
    case nextSlide = "next"
    case previousSlide = "previous"
    case startPresentation = "start"
    case endPresentation = "end"
    case blackScreen = "black"
    case keepalive = "keepalive"

    var keyCode: UInt16? { ... }
}
```

**Wire Format**: JSON encoded as `{"rawValue": "next"}`

---

## Mac App

### MacConnectionManager

Handles MultipeerConnectivity on the Mac side.

```swift
@MainActor
class MacConnectionManager: NSObject, ObservableObject {
    @Published var isConnected: Bool
    @Published var connectedDeviceName: String?

    func startAdvertising()
    func stopAdvertising()
}
```

| Property | Type | Description |
|----------|------|-------------|
| `isConnected` | `Bool` | True when iPhone is connected |
| `connectedDeviceName` | `String?` | Name of connected iPhone |

**Protocols Implemented**:
- `MCNearbyServiceAdvertiserDelegate`
- `MCSessionDelegate`

### KeystrokeSender

Injects keyboard events into the system.

```swift
class KeystrokeSender {
    static let shared: KeystrokeSender

    func sendNext()              // Sends Right Arrow (key code 124)
    func sendPrevious()          // Sends Left Arrow (key code 123)
    func sendStart()             // Sends Return (key code 36)
    func sendEnd()               // Sends Escape (key code 53)
    func sendBlackScreen()       // Sends B key (key code 11)
}
```

**Requirements**: Accessibility permission

### Key Codes Reference

| Action | Key Code | Key |
|--------|----------|-----|
| Next Slide | 124 | → Right Arrow |
| Previous Slide | 123 | ← Left Arrow |
| Start Presentation | 36 | Return |
| End Presentation | 53 | Escape |
| Black Screen | 11 | B key |

---

## iPhone App

### iPhoneConnectionManager

Handles MultipeerConnectivity on the iPhone side.

```swift
@MainActor
class iPhoneConnectionManager: NSObject, ObservableObject {
    @Published var isConnected: Bool
    @Published var availablePeers: [MCPeerID]
    @Published var connectedPeerName: String?

    func startBrowsing()
    func stopBrowsing()
    func connect(to peer: MCPeerID)
    func disconnect()
    func sendCommand(_ command: RemoteCommand)
}
```

| Property | Type | Description |
|----------|------|-------------|
| `isConnected` | `Bool` | True when connected to Mac |
| `availablePeers` | `[MCPeerID]` | Discovered Mac devices |
| `connectedPeerName` | `String?` | Name of connected Mac |

**Protocols Implemented**:
- `MCNearbyServiceBrowserDelegate`
- `MCSessionDelegate`

### PresentationTimer

Manages the presentation timer with haptic feedback.

```swift
@MainActor
class PresentationTimer: ObservableObject {
    @Published var isRunning: Bool
    @Published var elapsedTime: TimeInterval
    @Published var duration: TimeInterval
    @Published var hapticInterval: TimeInterval

    var progress: Double { elapsedTime / duration }

    func start()
    func pause()
    func reset()
}
```

| Property | Type | Description |
|----------|------|-------------|
| `isRunning` | `Bool` | Timer active state |
| `elapsedTime` | `TimeInterval` | Seconds elapsed |
| `duration` | `TimeInterval` | Total duration (0 = unlimited) |
| `hapticInterval` | `TimeInterval` | Seconds between haptic alerts |
| `progress` | `Double` | 0.0 to 1.0 progress value |

**Duration Presets**: 5, 10, 15, 20, 30 minutes, unlimited

**Haptic Intervals**: 30s, 1m, 2m, 5m

### SubscriptionManager

Handles StoreKit 2 subscription logic.

```swift
@Observable
class SubscriptionManager {
    var status: SubscriptionStatus

    func checkEntitlements() async
    func purchase(_ product: Product) async throws
    func restorePurchases() async
}
```

### SubscriptionStatus

```swift
enum SubscriptionStatus {
    case notDetermined
    case trial(daysRemaining: Int)
    case subscribed(expiresAt: Date?)
    case expired
}
```

### TrialTracker

Manages the 7-day trial period via Keychain.

```swift
class TrialTracker {
    var hasStartedTrial: Bool
    var trialStartDate: Date?
    var daysRemaining: Int
    var isTrialExpired: Bool

    func startTrial()
}
```

**Storage**: Keychain (survives app reinstall)

---

## SwiftUI Views

### Mac App Views

| View | Description |
|------|-------------|
| `ContentView` | Main menu bar content |
| `ConnectionStatusView` | Shows connection state |

### iPhone App Views

| View | Description |
|------|-------------|
| `SubscriptionGateView` | Entry point, checks subscription |
| `ContentView` | Main container |
| `ConnectionView` | Device discovery and connection |
| `RemoteControlView` | Slide navigation buttons |
| `TimerView` | Presentation timer |
| `TimerSettingsView` | Timer configuration sheet |
| `PaywallView` | Subscription purchase UI |

---

## Watch App

### WatchConnectionManager

Handles WatchConnectivity communication with the iPhone.

```swift
class WatchConnectionManager: NSObject, ObservableObject {
    @Published var isReachable: Bool
    @Published var isConnectedToMac: Bool

    func sendCommand(_ command: String)
    func nextSlide()
    func previousSlide()
}
```

| Property | Type | Description |
|----------|------|-------------|
| `isReachable` | `Bool` | True when iPhone is reachable |
| `isConnectedToMac` | `Bool` | True when iPhone is connected to Mac |

**Protocols Implemented**:
- `WCSessionDelegate`

**Retry Logic**: Commands are retried up to 3 times at 0.5s intervals if the iPhone is temporarily unreachable.

### GestureManager

Detects wrist flick gestures using CoreMotion for hands-free slide control.

```swift
class GestureManager: ObservableObject {
    @Published var isEnabled: Bool
    @Published var lastGesture: DetectedGesture?
    @Published var isInverted: Bool
    @Published var autoToggleWithWrist: Bool
    @Published var gestureLockEnabled: Bool
    @Published var noGoingBack: Bool
    @Published var isLocked: Bool
    @Published var lockProgress: CGFloat

    func start()
    func stop()
    func toggle()
}
```

| Property | Type | Description |
|----------|------|-------------|
| `isEnabled` | `Bool` | Whether gesture detection is active |
| `lastGesture` | `DetectedGesture?` | Most recently detected gesture (`.next` or `.previous`) |
| `isInverted` | `Bool` | Swap forward/backward flick directions |
| `autoToggleWithWrist` | `Bool` | Auto-enable on wrist raise, disable on wrist lower |
| `gestureLockEnabled` | `Bool` | Enable 3-second cooldown after each gesture |
| `noGoingBack` | `Bool` | Ignore backward flick gestures (forward-only navigation) |
| `isLocked` | `Bool` | Currently in lock cooldown period |
| `lockProgress` | `CGFloat` | Lock countdown progress (1.0 → 0.0) |

### Watch SwiftUI Views

| View | Description |
|------|-------------|
| `ContentView` | Next/previous buttons + timer display + double-tap gesture support; in flick mode, previous button is disabled when "No Going Back" is on |
| `SettingsView` | Watch app settings (gesture mode, gesture lock, no going back, invert gestures, auto-toggle, invert crown) |

**Timer Gestures**:
- **Tap**: Start/stop timer
- **Long press**: Reset timer to 00:00 with haptic feedback

---

## Bundle Identifiers

| App | Bundle ID |
|-----|-----------|
| Deck (Mac) | `com.dou.clicker-mac` |
| Deck (iOS) | `com.dou.clicker-ios` |
| DeckWatch (watchOS) | `com.dou.clicker-ios.watchkitapp` |

## StoreKit Product IDs

| Product | ID |
|---------|-----|
| Annual Subscription | `com.dou.deck.annual` |
