import ActivityKit
import Foundation

struct PresentationAttributes: ActivityAttributes {
    var macName: String

    struct ContentState: Codable, Hashable {
        /// When the current timer run started (nil if paused/stopped)
        var timerStartDate: Date?
        /// Seconds accumulated from previous runs before the current one
        var accumulatedSeconds: Int
        /// Whether the timer is currently running
        var isTimerRunning: Bool
        /// Total presentation duration in seconds (nil = no limit)
        var totalDuration: Int?
    }
}
