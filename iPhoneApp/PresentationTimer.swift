import Foundation
import SwiftUI
import CoreHaptics

// MARK: - Timer Configuration
struct TimerConfig: Equatable {
    var vibrationInterval: TimeInterval  // Seconds between vibrations
    var totalDuration: TimeInterval?     // Optional: total presentation time (for halfway/end alerts)
    var isEnabled: Bool = true
    
    static let presets: [(name: String, interval: TimeInterval)] = [
        ("30 sec", 30),
        ("1 min", 60),
        ("2 min", 120),
        ("5 min", 300),
        ("10 min", 600),
    ]
    
    static let durationPresets: [(name: String, duration: TimeInterval?)] = [
        ("No limit", nil),
        ("5 min", 300),
        ("10 min", 600),
        ("15 min", 900),
        ("20 min", 1200),
        ("30 min", 1800),
    ]
}

// MARK: - Presentation Timer
class PresentationTimer: ObservableObject {
    
    // MARK: - Published Properties
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning = false
    @Published var config = TimerConfig(vibrationInterval: 60, totalDuration: nil) {
        didSet { updateLiveActivity() }
    }
    @Published var lastVibratedAt: TimeInterval = 0
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var hapticEngine: CHHapticEngine?
    private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    // MARK: - Computed Properties
    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var remainingTime: TimeInterval? {
        guard let total = config.totalDuration else { return nil }
        return max(0, total - elapsedTime)
    }
    
    var formattedRemainingTime: String? {
        guard let remaining = remainingTime else { return nil }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "-%02d:%02d", minutes, seconds)
    }
    
    var progress: Double? {
        guard let total = config.totalDuration, total > 0 else { return nil }
        return min(1.0, elapsedTime / total)
    }
    
    // MARK: - Initialization
    init() {
        setupHaptics()
        impactGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    // MARK: - Haptic Setup
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            
            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
                do {
                    try self?.hapticEngine?.start()
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    // MARK: - Timer Controls
    /// The date when the current timer run started (used for Live Activity)
    private var timerStartDate: Date?

    func start() {
        guard !isRunning else { return }

        isRunning = true
        lastVibratedAt = elapsedTime
        timerStartDate = Date()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }

        // Keep timer running in background
        RunLoop.current.add(timer!, forMode: .common)
        updateLiveActivity()
    }

    func pause() {
        isRunning = false
        timerStartDate = nil
        timer?.invalidate()
        timer = nil
        updateLiveActivity()
    }

    func reset() {
        pause()
        elapsedTime = 0
        lastVibratedAt = 0
        updateLiveActivity()
    }

    // MARK: - Live Activity

    private func updateLiveActivity() {
        LiveActivityManager.shared.updateTimerState(
            startDate: timerStartDate,
            accumulatedSeconds: Int(elapsedTime),
            isRunning: isRunning,
            totalDuration: config.totalDuration.map { Int($0) }
        )
    }
    
    func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }
    
    // MARK: - Tick Handler
    private func tick() {
        elapsedTime += 1
        
        guard config.isEnabled else { return }
        
        // Check for interval vibration
        let timeSinceLastVibration = elapsedTime - lastVibratedAt
        if timeSinceLastVibration >= config.vibrationInterval {
            triggerIntervalVibration()
            lastVibratedAt = elapsedTime
        }
        
        // Check for special milestones
        if let total = config.totalDuration {
            // Halfway point (within 1 second)
            let halfway = total / 2
            if abs(elapsedTime - halfway) < 1 {
                triggerHalfwayVibration()
            }
            
            // Time's up
            if elapsedTime >= total && elapsedTime < total + 1 {
                triggerEndVibration()
            }
            
            // Overtime warning (every 30 seconds after time's up)
            if elapsedTime > total {
                let overtime = elapsedTime - total
                if overtime.truncatingRemainder(dividingBy: 30) < 1 {
                    triggerOvertimeVibration()
                }
            }
        }
    }
    
    // MARK: - Vibration Patterns
    
    /// Single pulse for regular interval
    func triggerIntervalVibration() {
        playHapticPattern(intensity: 0.7, sharpness: 0.5, count: 1)
        print("⏱️ Interval vibration at \(formattedTime)")
    }
    
    /// Triple pulse for halfway point
    private func triggerHalfwayVibration() {
        playHapticPattern(intensity: 0.8, sharpness: 0.6, count: 3, interval: 0.15)
        print("⏱️ Halfway vibration at \(formattedTime)")
    }
    
    /// Long continuous vibration for end
    private func triggerEndVibration() {
        playLongVibration(duration: 1.0)
        notificationGenerator.notificationOccurred(.warning)
        print("⏱️ End vibration at \(formattedTime)")
    }
    
    /// Double pulse for overtime
    private func triggerOvertimeVibration() {
        playHapticPattern(intensity: 1.0, sharpness: 1.0, count: 2, interval: 0.1)
        print("⏱️ Overtime vibration at \(formattedTime)")
    }
    
    // MARK: - Haptic Playback
    
    private func playHapticPattern(intensity: Float, sharpness: Float, count: Int, interval: TimeInterval = 0.2) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            // Fallback to basic haptics
            for i in 0..<count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                    self.impactGenerator.impactOccurred(intensity: CGFloat(intensity))
                }
            }
            return
        }
        
        var events: [CHHapticEvent] = []
        
        for i in 0..<count {
            let time = TimeInterval(i) * interval
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: time
            )
            events.append(event)
        }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play haptic pattern: \(error)")
            impactGenerator.impactOccurred()
        }
    }
    
    private func playLongVibration(duration: TimeInterval) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            notificationGenerator.notificationOccurred(.error)
            return
        }
        
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ],
            relativeTime: 0,
            duration: duration
        )
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play long vibration: \(error)")
            notificationGenerator.notificationOccurred(.error)
        }
    }
    
    // MARK: - Manual Test
    func testVibration() {
        triggerIntervalVibration()
    }
}
