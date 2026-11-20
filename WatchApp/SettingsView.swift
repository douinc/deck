import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gestureManager: GestureManager
    @AppStorage("gestureMode") private var gestureMode = "doubleTap"
    @AppStorage("invertCrown") private var invertCrown = false
    @AppStorage("hasSeenWatchTips") private var hasSeenWatchTips = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Picker("Gesture Mode", selection: $gestureMode) {
                    Label("Double Tap", systemImage: "hand.tap")
                        .tag("doubleTap")
                    Label("Wrist Flick", systemImage: "hand.wave")
                        .tag("flickWrist")
                }
            } footer: {
                Text(gestureMode == "doubleTap"
                     ? "Tap your finger and thumb together twice for the next slide (Series 9 or newer)."
                     : "Flick your wrist forward for next, backward for previous.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            if gestureMode == "flickWrist" {
                Section {
                    Toggle(isOn: $gestureManager.gestureLockEnabled) {
                        Text("Gesture Lock")
                            .font(.system(size: 15))
                    }
                } footer: {
                    Text("Wait 3 seconds between flicks so you don’t skip slides by accident.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Section {
                    Toggle(isOn: $gestureManager.noGoingBack) {
                        Text("No Going Back")
                            .font(.system(size: 15))
                    }
                } footer: {
                    Text("Only move forward. Backward flicks are ignored.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Section {
                    Toggle(isOn: $gestureManager.isInverted) {
                        Text("Invert Gestures")
                            .font(.system(size: 15))
                    }
                } footer: {
                    Text(gestureManager.isInverted
                         ? "Counterclockwise → Next\nClockwise → Previous"
                         : "Clockwise → Next\nCounterclockwise → Previous")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Section {
                    Toggle(isOn: $gestureManager.autoToggleWithWrist) {
                        Text("Auto-toggle with Wrist")
                            .font(.system(size: 15))
                    }
                } footer: {
                    Text("Flicks turn on when you raise your wrist and off when you lower it.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Toggle(isOn: $invertCrown) {
                    Label("Invert Crown", systemImage: "digitalcrown.horizontal.arrow.counterclockwise")
                        .font(.system(size: 15))
                }
            } footer: {
                Text(invertCrown
                     ? "Crown clockwise = previous slide, counterclockwise = next slide."
                     : "Crown clockwise = next slide, counterclockwise = previous slide.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Section {
                Button {
                    hasSeenWatchTips = false
                    dismiss()
                } label: {
                    Label("Show Tips", systemImage: "lightbulb")
                        .font(.system(size: 15))
                }
            } footer: {
                Text("See how to change slides from your watch again.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(GestureManager())
    }
}
