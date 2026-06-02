import ActivityKit
import SwiftUI
import WidgetKit

struct PresentationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PresentationAttributes.self) { context in
            // Lock Screen banner
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.macName, systemImage: "desktopcomputer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let total = context.state.totalDuration {
                        remainingText(state: context.state, total: total)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    timerDisplay(state: context.state)
                        .font(.system(size: 32, weight: .light, design: .monospaced))
                        .foregroundStyle(timerColor(state: context.state))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if let progress = progress(state: context.state) {
                        ProgressView(value: min(progress, 1.0))
                            .tint(progressColor(progress))
                    }
                }
            } compactLeading: {
                timerDisplay(state: context.state)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(timerColor(state: context.state))
            } compactTrailing: {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.green)
            } minimal: {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(context.state.isTimerRunning ? .green : .secondary)
            }
        }
    }

    // MARK: - Timer Display

    @ViewBuilder
    private func timerDisplay(state: PresentationAttributes.ContentState) -> some View {
        if state.isTimerRunning, let startDate = state.timerStartDate {
            // Synthetic start = startDate - accumulatedSeconds
            // Text(date, style: .timer) counts up from the given date
            let syntheticStart = startDate.addingTimeInterval(-Double(state.accumulatedSeconds))
            Text(syntheticStart, style: .timer)
                .multilineTextAlignment(.center)
        } else {
            // Paused: show static time
            Text(formatTime(state.accumulatedSeconds))
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func remainingText(state: PresentationAttributes.ContentState, total: Int) -> some View {
        if state.isTimerRunning, let startDate = state.timerStartDate {
            let endDate = startDate.addingTimeInterval(Double(total - state.accumulatedSeconds))
            Text(endDate, style: .timer)
                .multilineTextAlignment(.trailing)
        } else {
            let remaining = max(0, total - state.accumulatedSeconds)
            Text("-\(formatTime(remaining))")
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func timerColor(state: PresentationAttributes.ContentState) -> Color {
        guard let total = state.totalDuration, total > 0 else { return .white }
        let elapsed = state.accumulatedSeconds
        if elapsed >= total { return .red }
        if elapsed >= Int(Double(total) * 0.9) { return .orange }
        return .white
    }

    private func progress(state: PresentationAttributes.ContentState) -> Double? {
        guard let total = state.totalDuration, total > 0 else { return nil }
        return Double(state.accumulatedSeconds) / Double(total)
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress >= 1.0 { return .red }
        if progress >= 0.9 { return .orange }
        if progress >= 0.75 { return .yellow }
        return .green
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<PresentationAttributes>

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.green)
                    Text(context.attributes.macName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let total = context.state.totalDuration {
                    remainingLabel(total: total)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Timer
            timerText
                .font(.system(size: 36, weight: .light, design: .monospaced))
                .foregroundStyle(timerColor)
                .frame(maxWidth: .infinity, alignment: .center)

            // Progress bar
            if let total = context.state.totalDuration, total > 0 {
                let progress = min(Double(context.state.accumulatedSeconds) / Double(total), 1.0)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.15))
                        Capsule()
                            .fill(progressColor(progress))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.7))
    }

    @ViewBuilder
    private var timerText: some View {
        if context.state.isTimerRunning, let startDate = context.state.timerStartDate {
            let syntheticStart = startDate.addingTimeInterval(-Double(context.state.accumulatedSeconds))
            Text(syntheticStart, style: .timer)
        } else {
            Text(formatTime(context.state.accumulatedSeconds))
        }
    }

    @ViewBuilder
    private func remainingLabel(total: Int) -> some View {
        if context.state.isTimerRunning, let startDate = context.state.timerStartDate {
            let endDate = startDate.addingTimeInterval(Double(total - context.state.accumulatedSeconds))
            HStack(spacing: 2) {
                Text("remaining")
                Text(endDate, style: .timer)
            }
        } else {
            let remaining = max(0, total - context.state.accumulatedSeconds)
            Text("-\(formatTime(remaining)) remaining")
        }
    }

    private var timerColor: Color {
        guard let total = context.state.totalDuration, total > 0 else { return .white }
        let elapsed = context.state.accumulatedSeconds
        if elapsed >= total { return .red }
        if elapsed >= Int(Double(total) * 0.9) { return .orange }
        return .white
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress >= 1.0 { return .red }
        if progress >= 0.9 { return .orange }
        if progress >= 0.75 { return .yellow }
        return .green
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
