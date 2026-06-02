import ActivityKit
import Foundation

class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<PresentationAttributes>?

    private init() {}

    // MARK: - Start / End

    func startActivity(macName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("🔴 Live Activities not enabled")
            return
        }

        // End any existing activity first
        endActivity()

        let attributes = PresentationAttributes(macName: macName)
        let initialState = PresentationAttributes.ContentState(
            timerStartDate: nil,
            accumulatedSeconds: 0,
            isTimerRunning: false,
            totalDuration: nil
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            print("🟢 Live Activity started")
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }

    func endActivity() {
        guard let activity = activity else { return }

        let finalState = PresentationAttributes.ContentState(
            timerStartDate: nil,
            accumulatedSeconds: 0,
            isTimerRunning: false,
            totalDuration: nil
        )

        Task {
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            print("🔴 Live Activity ended")
        }

        self.activity = nil
    }

    // MARK: - Timer Updates

    func updateTimerState(
        startDate: Date?,
        accumulatedSeconds: Int,
        isRunning: Bool,
        totalDuration: Int?
    ) {
        guard let activity = activity else { return }

        let state = PresentationAttributes.ContentState(
            timerStartDate: startDate,
            accumulatedSeconds: accumulatedSeconds,
            isTimerRunning: isRunning,
            totalDuration: totalDuration
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }
}
