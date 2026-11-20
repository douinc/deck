import Foundation
import CoreMotion
import UIKit

/// Turns the iPhone into an air mouse while the pointer button is held.
///
/// - Hold: the phone's rotation drives the Mac cursor (like a laser pointer).
/// - Quick tap: left click at the current cursor position.
final class PointerController: ObservableObject {

    /// True while the pointer button is pressed
    @Published private(set) var isActive = false

    /// Where pointer messages go (set by the view that owns the connection)
    var send: ((PointerMessage) -> Void)?

    static let sensitivityKey = "pointerSensitivity"

    // MARK: - Tuning
    private let updateInterval: TimeInterval = 1.0 / 60.0
    private let tapThreshold: TimeInterval = 0.18     // Shorter presses are clicks
    private let baseGain: Double = 1800               // Points of cursor travel per radian
    private let deadzone: Double = 0.015              // rad/s, hides hand tremor
    private let smoothing: Double = 0.5               // 0 = raw, 1 = frozen

    // MARK: - State
    private let motion = CMMotionManager()
    private var pressStart: Date?
    private var tracking = false
    private var gain: Double = 1800
    private var smoothedYaw: Double = 0
    private var smoothedPitch: Double = 0
    private let clickHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let engageHaptic = UIImpactFeedbackGenerator(style: .soft)

    // MARK: - Button Events

    func pressBegan() {
        guard !isActive else { return }
        isActive = true
        pressStart = Date()
        tracking = false
        smoothedYaw = 0
        smoothedPitch = 0

        let stored = UserDefaults.standard.double(forKey: Self.sensitivityKey)
        gain = baseGain * (stored > 0 ? stored : 1.0)

        clickHaptic.prepare()
        engageHaptic.prepare()
        startMotion()
    }

    func pressEnded() {
        guard isActive else { return }
        isActive = false
        motion.stopDeviceMotionUpdates()

        if let start = pressStart, Date().timeIntervalSince(start) < tapThreshold {
            send?(.click)
            clickHaptic.impactOccurred()
        }
        pressStart = nil
    }

    /// Stops tracking without clicking (view disappeared, app backgrounded)
    func cancel() {
        isActive = false
        pressStart = nil
        motion.stopDeviceMotionUpdates()
    }

    // MARK: - Motion

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = updateInterval
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.handle(data)
        }
    }

    private func handle(_ data: CMDeviceMotion) {
        guard isActive, let start = pressStart else { return }

        // Ignore motion until the press is clearly a hold, so a tap-to-click
        // doesn't nudge the cursor off its target.
        guard Date().timeIntervalSince(start) >= tapThreshold else { return }
        if !tracking {
            tracking = true
            engageHaptic.impactOccurred()
        }

        let w = data.rotationRate   // rad/s, device frame
        let g = data.gravity        // unit vector pointing down, device frame

        // Horizontal: rotation about the world's vertical axis, so it works
        // whether the phone is held flat like a remote or upright.
        let yawRate = w.x * g.x + w.y * g.y + w.z * g.z

        // Vertical: rotation about the horizontal axis perpendicular to the
        // phone's long edge (g × ŷ). Falls back to the device x-axis when the
        // phone points straight up/down and that axis is undefined.
        let lateral = (g.x * g.x + g.z * g.z).squareRoot()
        let pitchRate = lateral > 0.2 ? (-g.z * w.x + g.x * w.z) / lateral : w.x

        smoothedYaw = smoothedYaw * smoothing + yawRate * (1 - smoothing)
        smoothedPitch = smoothedPitch * smoothing + pitchRate * (1 - smoothing)

        let yaw = abs(smoothedYaw) > deadzone ? smoothedYaw : 0
        let pitch = abs(smoothedPitch) > deadzone ? smoothedPitch : 0

        // Turning right moves the cursor right; tilting up moves it up.
        let dx = yaw * updateInterval * gain
        let dy = -pitch * updateInterval * gain

        guard abs(dx) >= 0.1 || abs(dy) >= 0.1 else { return }
        send?(.move(dx: dx, dy: dy))
    }
}
