import Foundation
import CoreMotion
import WatchKit
import Combine

/// Detects wrist flick gestures using CoreMotion for hands-free slide control.
///
/// Default gesture mapping:
/// - Flick wrist forward (clockwise, away from body) → Next slide
/// - Flick wrist backward (counterclockwise, toward body) → Previous slide
///
/// Inverted gesture mapping:
/// - Counterclockwise → Next slide
/// - Clockwise → Previous slide
///
/// Uses the gyroscope rotation rate around the x-axis, which corresponds
/// to wrist flexion/extension — the natural "flick forward" and "pull back" motion.
class GestureManager: ObservableObject {

    // MARK: - Published State

    @Published var isEnabled = false
    @Published var lastGesture: DetectedGesture?
    @Published var isInverted: Bool {
        didSet { UserDefaults.standard.set(isInverted, forKey: "gestureInverted") }
    }
    @Published var autoToggleWithWrist: Bool {
        didSet { UserDefaults.standard.set(autoToggleWithWrist, forKey: "gestureAutoToggle") }
    }
    @Published var gestureLockEnabled: Bool {
        didSet { UserDefaults.standard.set(gestureLockEnabled, forKey: "gestureLockEnabled") }
    }
    @Published var noGoingBack: Bool {
        didSet { UserDefaults.standard.set(noGoingBack, forKey: "gestureNoGoingBack") }
    }
    @Published var isLocked: Bool = false
    @Published var lockProgress: CGFloat = 0.0

    enum DetectedGesture: Equatable {
        case next
        case previous
    }

    // MARK: - Callbacks

    var onNextSlide: (() -> Void)?
    var onPreviousSlide: (() -> Void)?

    // MARK: - Configuration

    /// Minimum rotation rate (rad/s) to trigger a gesture.
    /// Higher = less sensitive, fewer false positives.
    private let rotationThreshold: Double = 3.0

    /// Minimum time between gesture triggers to prevent double-fires.
    private let cooldownInterval: TimeInterval = 0.8

    /// Duration of the gesture lock period.
    private let lockDuration: TimeInterval = 3.0

    /// Motion update frequency in Hz.
    private let updateFrequency: Double = 50.0

    // MARK: - Private State

    private let motionManager = CMMotionManager()
    private var lastTriggerTime: Date = .distantPast
    private let motionQueue = OperationQueue()
    private var lockTimer: Timer?

    // MARK: - Initialization

    init() {
        self.isInverted = UserDefaults.standard.bool(forKey: "gestureInverted")
        self.autoToggleWithWrist = UserDefaults.standard.bool(forKey: "gestureAutoToggle")
        self.gestureLockEnabled = UserDefaults.standard.bool(forKey: "gestureLockEnabled")
        self.noGoingBack = UserDefaults.standard.bool(forKey: "gestureNoGoingBack")
        motionQueue.name = "com.dou.deck.gesture"
        motionQueue.maxConcurrentOperationCount = 1
    }

    // MARK: - Start / Stop

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            print("⌚ Device motion not available")
            return
        }
        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / updateFrequency

        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let self, let motion else {
                if let error {
                    print("⌚ Motion error: \(error.localizedDescription)")
                }
                return
            }
            self.processMotion(motion)
        }

        DispatchQueue.main.async {
            self.isEnabled = true
        }
        print("⌚ Gesture detection started")
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        DispatchQueue.main.async {
            self.isEnabled = false
            self.lastGesture = nil
            self.lockTimer?.invalidate()
            self.lockTimer = nil
            self.isLocked = false
            self.lockProgress = 0
        }
        print("⌚ Gesture detection stopped")
    }

    func toggle() {
        if isEnabled {
            stop()
        } else {
            start()
        }
    }

    // MARK: - Motion Processing

    private func processMotion(_ motion: CMDeviceMotion) {
        // Use rotation rate around x-axis: wrist flexion (forward flick) / extension (backward flick)
        let rotationX = motion.rotationRate.x

        guard abs(rotationX) > rotationThreshold else { return }

        let now = Date()
        // Determine gesture direction before cooldown check so we can skip
        // backward gestures without consuming the cooldown window.
        let isInverted = self.isInverted
        let gesture: DetectedGesture = (rotationX > 0) != isInverted ? .next : .previous

        // Skip previous-slide gestures when "No Going Back" is enabled
        if gesture == .previous && self.noGoingBack { return }

        let effectiveCooldown = gestureLockEnabled ? lockDuration : cooldownInterval
        guard now.timeIntervalSince(lastTriggerTime) >= effectiveCooldown else { return }
        lastTriggerTime = now

        let lockEnabled = self.gestureLockEnabled

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastGesture = gesture

            // Play strong directional haptic so the user clearly feels the gesture was recognized
            let device = WKInterfaceDevice.current()
            switch gesture {
            case .next:
                device.play(.directionUp)
                // Follow up with a second tap after a short delay for emphasis
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    device.play(.directionUp)
                }
                self.onNextSlide?()
            case .previous:
                device.play(.directionDown)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    device.play(.directionDown)
                }
                self.onPreviousSlide?()
            }

            if lockEnabled {
                self.startLockCountdown(for: gesture)
            } else {
                // Clear visual indicator after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.lastGesture == gesture {
                        self.lastGesture = nil
                    }
                }
            }
        }
    }

    // MARK: - Gesture Lock

    private func startLockCountdown(for gesture: DetectedGesture) {
        lockTimer?.invalidate()
        isLocked = true
        lockProgress = 1.0

        let startTime = Date()
        lockTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= self.lockDuration {
                timer.invalidate()
                self.lockTimer = nil
                self.isLocked = false
                self.lockProgress = 0
                self.lastGesture = nil
            } else {
                self.lockProgress = CGFloat(1.0 - elapsed / self.lockDuration)
            }
        }
    }
}
