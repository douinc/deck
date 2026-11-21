# API Reference

The wire protocol, the key classes in each app, and the identifiers and stored settings they use. Signatures are abbreviated; the source is the authority.

## Shared (`Shared/`)

### RemoteCommand

```swift
enum RemoteCommand: String, Codable {
    case nextSlide = "next"
    case previousSlide = "previous"
    case startPresentation = "start"
    case endPresentation = "end"
    case blackScreen = "black"
    case keepalive = "keepalive"          // iPhone → Mac liveness probe
    case keepaliveAck = "keepalive_ack"   // Mac → iPhone reply

    var keyCode: UInt16? { ... }
}
```

**Wire format:** the raw value as a UTF-8 string, for example `next`. It is not JSON.

| Command | Key code | Key |
|---------|----------|-----|
| `nextSlide` | 124 | Right arrow |
| `previousSlide` | 123 | Left arrow |
| `startPresentation` | 36 | Return |
| `endPresentation` | 53 | Escape |
| `blackScreen` | 11 | B |
| `keepalive`, `keepaliveAck` | — | No keystroke |

### PointerMessage

```swift
enum PointerMessage: Equatable {
    case move(dx: Double, dy: Double)   // Points; y grows downward
    case click                          // Left click at the cursor
    case spotlight(Bool)                // Dim the Mac's screen around the cursor

    var wireString: String { ... }      // "ptr:m:4.2,-1.0", "ptr:click", "ptr:spot:1"
    init?(wireString: String)
}
```

### RemoteServiceConfig

```swift
struct RemoteServiceConfig {
    static let serviceType = "clickerremote"
    static let displayName = "Deck"
    static func persistentPeerID(displayName: String) -> MCPeerID   // Mac and iPhone only
}
```

### LocalNetworkPermissionMonitor

```swift
final class LocalNetworkPermissionMonitor: ObservableObject {
    @Published private(set) var isDenied: Bool
    func start()   // Starts or restarts the Bonjour probe; call on the main thread
    func stop()
}
```

Detects a denied Local Network permission. It cannot confirm a grant. Not compiled for watchOS.

---

## iPhone app (`iPhoneApp/`)

### iPhoneConnectionManager

Browsing, the session, keepalives, reconnection, and the relay for the watch.

```swift
class iPhoneConnectionManager: NSObject, ObservableObject {
    @Published var isConnected: Bool
    @Published var availableMacs: [MCPeerID]
    @Published var connectedMac: MCPeerID?
    @Published private(set) var localNetworkDenied: Bool
    @Published private(set) var isSearchTakingLong: Bool
    @Published private(set) var connectingMacName: String?
    @Published private(set) var failedMacName: String?

    func beginDiscovery()             // Called when onboarding finishes
    func handleAppBecameActive()      // Restarts the browser
    func connectTo(_ peer: MCPeerID)
    func cancelConnecting()
    func retryFailedConnection()
    func disconnect()                 // Also clears auto-reconnect

    func sendCommand(_ command: RemoteCommand)
    func sendPointer(_ message: PointerMessage)
    func nextSlide()
    func previousSlide()
    func click()
}
```

| Property | Meaning |
|----------|---------|
| `availableMacs` | Discovered Macs, de-duplicated by display name |
| `localNetworkDenied` | iOS has blocked Local Network access |
| `isSearchTakingLong` | No Mac found after about 10 s; the UI shows a checklist |
| `connectingMacName` | An invitation is in flight |
| `failedMacName` | The last first-time connection attempt failed |

Conforms to `MCSessionDelegate`, `MCNearbyServiceBrowserDelegate` and `WCSessionDelegate`. Debug state (`debugLogs`, `sessionState`, `browserState`, `lastError`, `debugInfo`) feeds `ConnectionDebugView`.

### ArcLayout, ArcControl, Handedness

```swift
struct ArcLayout {
    let size: CGSize
    let hand: Handedness
    var unit: CGFloat            // min(width, height × 0.55)
    var pivot: CGPoint
    var innerRadius: CGFloat     // unit × 0.70
    var outerRadius: CGFloat     // unit × 1.08
    var timerRadius: CGFloat
    var readoutRadius: CGFloat

    func point(radius: CGFloat, degrees: Double) -> CGPoint
    func normalized(_ point: CGPoint) -> CGPoint
    func point(normalized: CGPoint) -> CGPoint
    func arc(radius: CGFloat, from: Double, to: Double) -> Path
}

enum ArcControl: String, CaseIterable {
    case previous, next, pointer, resetTimer, toggleTimer, settings
    static func loadPositions() -> [ArcControl: CGPoint]
    static func savePositions(_ positions: [ArcControl: CGPoint])
}

enum Handedness: String, CaseIterable { case left, right }
```

### PresentationTimer

```swift
struct TimerConfig: Equatable {
    var vibrationInterval: TimeInterval   // Default 60
    var totalDuration: TimeInterval?      // nil = no limit
    var isEnabled: Bool                   // Haptic alerts
}

class PresentationTimer: ObservableObject {
    @Published var elapsedTime: TimeInterval
    @Published var isRunning: Bool
    @Published var config: TimerConfig

    var remainingTime: TimeInterval?
    var progress: Double?                 // 0...1, nil with no limit

    func start()
    func pause()
    func reset()
    func toggle()
    func testVibration()
}
```

Interval presets: 30 sec, 1, 2, 5, 10 min. Duration presets: no limit, 5, 10, 15, 20, 30 min. The timer arc sets any whole minute from 0 to 30.

### TimerTint

```swift
enum TimerTint {
    static let onTrack   // Mint,   #8FEDCC
    static let wrapUp    // Amber,  #FFD17A
    static let urgent    // Orange, #FF9E5C
    static let over      // Coral,  #FF6B66
    static func color(progress: Double) -> Color   // 0.75, 0.9 and 1.0 thresholds
}
```

The landing page and App Store panels use these same four colors.

### PointerController

```swift
final class PointerController: ObservableObject {
    @Published private(set) var isActive: Bool
    var send: ((PointerMessage) -> Void)?

    func pressBegan()
    func pressEnded()   // A press under 0.18 s sends .click
    func cancel()       // Stops without clicking
}
```

### Subscription

```swift
let subscriptionProductID = "com.dou.clicker_ios.subscription.yearly"

@MainActor @Observable
final class SubscriptionManager {
    private(set) var status: AppSubscriptionStatus
    var hasAccess: Bool
    var trialDaysRemaining: Int?

    func loadProducts() async
    func purchase(_ product: Product) async throws -> Bool
    func restorePurchases() async
    func updateSubscriptionStatus() async
}

enum AppSubscriptionStatus: Equatable {
    case notDetermined
    case trial(daysRemaining: Int)
    case subscribed(expirationDate: Date)
    case expired
}

final class TrialTracker {
    var trialStartDate: Date?   // Keychain
    var hasTrialStarted: Bool
    var isTrialActive: Bool     // Within 7 days of the start date
    var daysRemaining: Int
    func startTrial()
}
```

### Live Activity

```swift
struct PresentationAttributes: ActivityAttributes {
    var macName: String
    struct ContentState: Codable, Hashable {
        var timerStartDate: Date?
        var accumulatedSeconds: Int
        var isTimerRunning: Bool
        var totalDuration: Int?
    }
}

class LiveActivityManager {
    static let shared: LiveActivityManager
    func startActivity(macName: String)
    func endActivity()
    func updateTimerState(startDate: Date?, accumulatedSeconds: Int, isRunning: Bool, totalDuration: Int?)
}
```

### Views

| View | File | Role |
|------|------|------|
| `OnboardingView` | `OnboardingView.swift` | Three first-launch pages |
| `SubscriptionGateView` | `PresentationRemoteiPhoneApp.swift` | Routes on subscription status |
| `ConnectionView` | same | Searching, found, connecting, failed, denied |
| `HelpSheet` | same | Setup steps, common problems, diagnostics |
| `ArcRemoteView` | `ArcRemoteView.swift` | The remote |
| `TimerArc`, `TimerReadout` | same | Time gauge, limit picker, digits |
| `ArcButton`, `PointerButton` | same | Round controls |
| `RemoteSettingsView` | `PresentationRemoteiPhoneApp.swift` | Settings sheet |
| `RemoteTipsOverlay` | same | First-connection tips |
| `PaywallView` | `PaywallView.swift` | `SubscriptionStoreView` wrapper |
| `ConnectionDebugView` | `DebugView.swift` | Connection diagnostics |

---

## Mac app (`MacApp/`)

### MacConnectionManager

```swift
class MacConnectionManager: NSObject, ObservableObject {
    @Published var isAdvertising: Bool
    @Published var connectedDevices: [MCPeerID]
    @Published var lastCommand: RemoteCommand?
    @Published var statusMessage: String
    @Published private(set) var localNetworkDenied: Bool

    var onCommandReceived: ((RemoteCommand) -> Void)?
    var onPointerReceived: ((PointerMessage) -> Void)?

    func startAdvertising()                             // Safe to call repeatedly
    func stopAdvertising(userInitiated: Bool = false)   // true = stay stopped
    func disconnect()
}
```

Conforms to `MCSessionDelegate` and `MCNearbyServiceAdvertiserDelegate`.

### Services

```swift
final class KeystrokeService {
    static let shared: KeystrokeService
    @discardableResult func sendCommand(_ command: RemoteCommand) -> Bool
    func nextSlide()
    func previousSlide()
    func startPresentation()
    func endPresentation()
}

final class PointerService {
    static let shared: PointerService
    @discardableResult func handle(_ message: PointerMessage) -> Bool
}

final class SpotlightOverlay {
    static let shared: SpotlightOverlay
    func setActive(_ active: Bool)
    func keepAlive()
}

final class PermissionService: ObservableObject {
    static let shared: PermissionService
    @Published private(set) var hasAccessibilityPermission: Bool
    let permissionGranted: PassthroughSubject<Void, Never>   // Denied → granted while running

    @discardableResult func checkPermissionStatus() -> Bool
    func requestPermission()
    func openSystemPreferences()
    func startPolling(interval: TimeInterval = 1.0)
    func stopPolling()
}

enum AppRelauncher { static func relaunch() }

final class UpdateChecker: ObservableObject {
    @Published var availableUpdate: String?
    func checkIfNeeded()   // At most once every 24 hours
}

final class PreferencesManager: ObservableObject {
    static let shared: PreferencesManager
    @Published var hasCompletedOnboarding: Bool
    @Published var debugMenuEnabled: Bool
    @Published var launchAtLogin: Bool
    func markOnboardingComplete()
    func reset()
}
```

`KeystrokeService` and `PointerService` return `false` when Accessibility permission is missing.

### Coordinator and views

| Type | Role |
|------|------|
| `AppCoordinator` | Owns services and view models; launch sequence; relaunch after Accessibility is granted |
| `MenuBarViewModel` / `MenuBarView` | Menu content and actions |
| `MenuBarIcon` | Template icon, dimmed when disconnected |
| `WelcomeViewModel` / `WelcomeView` | Setup guide: Welcome → Allow Deck → Connect iPhone → All Set |
| `SettingsView` | Launch at Login, permissions, debug menu, reset onboarding |
| `MacDebugView` | Connection logs, restart session |

---

## Watch app (`WatchApp/`)

### WatchConnectionManager

```swift
class WatchConnectionManager: NSObject, ObservableObject {
    @Published var isReachable: Bool
    @Published var isConnectedToMac: Bool

    func sendCommand(_ command: String)
    func nextSlide()
    func previousSlide()
}
```

Commands are retried up to 3 times at 0.5 s intervals when the iPhone is unreachable.

### GestureManager

```swift
class GestureManager: ObservableObject {
    @Published var isEnabled: Bool
    @Published var lastGesture: DetectedGesture?   // .next or .previous
    @Published var isInverted: Bool
    @Published var autoToggleWithWrist: Bool
    @Published var gestureLockEnabled: Bool
    @Published var noGoingBack: Bool
    @Published var isLocked: Bool
    @Published var lockProgress: CGFloat           // 1.0 → 0.0

    var onNextSlide: (() -> Void)?
    var onPreviousSlide: (() -> Void)?

    func start()
    func stop()
    func toggle()
}
```

| Constant | Value |
|----------|-------|
| Rotation threshold | 3.0 rad/s about the x-axis |
| Cooldown | 0.8 s |
| Gesture lock | 3.0 s |
| Sample rate | 50 Hz |

### ExtendedSessionManager

```swift
class ExtendedSessionManager: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    func start()
    func stop()
}
```

### Views

| View | Role |
|------|------|
| `ContentView` | Double Tap layout or Wrist Flick layout, timer, Crown handling |
| `SettingsView` | Gesture mode, flick options, Invert Crown, Show Tips |
| `WatchTipsView` | First-run cards |
| `WatchConnectGuideView` | Shown until the iPhone is connected to a Mac |

---

## Stored settings

### iPhone (UserDefaults)

| Key | Type | Meaning |
|-----|------|---------|
| `hasCompletedOnboarding` | Bool | Onboarding finished; discovery may start |
| `hasSeenRemoteTips` | Bool | First-connection tips dismissed |
| `handedness` | String | `left` or `right` |
| `arcButtonPositions` | Dictionary | Custom button positions, normalized |
| `nextButtonClicks` | Bool | Next sends a left click |
| `pointerSensitivity` | Double | 0.4 to 2.5, default 1.0 |
| `pointerSpotlight` | Bool | Spotlight while the pointer is held |
| `DeckCachedPeerIDData`, `DeckCachedPeerIDName` | Data, String | Persistent `MCPeerID` |

Keychain: `com.dou.clicker-ios.trialStartDate` holds the trial start date.

### Mac (UserDefaults)

| Key | Type | Meaning |
|-----|------|---------|
| `hasCompletedOnboarding` | Bool | Setup guide finished |
| `debugMenuEnabled` | Bool | Show the Debug submenu |
| `lastUpdateCheckDate` | Date | Last GitHub release check |
| `DeckCachedPeerIDData`, `DeckCachedPeerIDName` | Data, String | Persistent `MCPeerID` |

### Watch (UserDefaults)

| Key | Type | Meaning |
|-----|------|---------|
| `gestureMode` | String | `doubleTap` (default) or `flickWrist` |
| `gestureLockEnabled` | Bool | 3-second lock between flicks |
| `gestureNoGoingBack` | Bool | Ignore backward flicks |
| `gestureInverted` | Bool | Swap flick directions |
| `gestureAutoToggle` | Bool | Flicks follow wrist raise |
| `invertCrown` | Bool | Swap Crown direction |
| `hasSeenWatchTips` | Bool | First-run tips dismissed |

---

## Identifiers

| Item | Value |
|------|-------|
| Mac bundle ID | `com.dou.clicker-mac` |
| iPhone bundle ID | `com.dou.clicker-ios` |
| Watch bundle ID | `com.dou.clicker-ios.watchkitapp` |
| Live Activity bundle ID | `com.dou.clicker-ios.LiveActivity` |
| Subscription product ID | `com.dou.clicker_ios.subscription.yearly` |
| Bonjour services | `_clickerremote._tcp`, `_clickerremote._udp` |
| Team ID | `HD35YQ72U4` (DOU Inc.) |
| App Store ID | `6758130180` |
