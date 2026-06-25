import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gestureManager: GestureManager
    @AppStorage("gestureMode") private var gestureMode = "doubleTap"
    @AppStorage("invertCrown") private var invertCrown = false
    @AppStorage("crownControlEnabled") private var crownControlEnabled = true
    @AppStorage("crownDetentsPerSlide") private var crownDetentsPerSlide = 1

    private var crownFooterText: String {
        guard crownControlEnabled else {
            return "Digital Crown slide navigation is disabled to prevent accidental slide changes."
        }

        let direction = invertCrown
            ? "clockwise = previous slide, counterclockwise = next slide"
            : "clockwise = next slide, counterclockwise = previous slide"

        let sensitivity: String
        switch crownDetentsPerSlide {
        case 1:
            sensitivity = "Fast: every crown detent advances a slide."
        case 2:
            sensitivity = "Balanced: two detents are required per slide."
        case 3:
            sensitivity = "Deliberate: three detents are required per slide."
        default:
            sensitivity = "Locked-in: five detents are required per slide."
        }

        return "\(sensitivity) Crown \(direction)."
    }

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
                     ? "Double-tap gesture triggers next slide (watchOS 11+, Series 9+)."
                     : "Flick your wrist to navigate slides hands-free.")
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
                    Text("After a gesture, lock out further gestures for 3 seconds to prevent accidental triggers.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Section {
                    Toggle(isOn: $gestureManager.noGoingBack) {
                        Text("No Going Back")
                            .font(.system(size: 15))
                    }
                } footer: {
                    Text("Disable previous slide gesture. Only forward flicks will be recognized.")
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
                    Text("Gestures enable on wrist raise and disable on wrist lower.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Toggle(isOn: $crownControlEnabled) {
                    Label("Crown Control", systemImage: "digitalcrown.horizontal.arrow.clockwise")
                        .font(.system(size: 15))
                }

                Picker("Sensitivity", selection: $crownDetentsPerSlide) {
                    Text("Fast").tag(1)
                    Text("Balanced").tag(2)
                    Text("Deliberate").tag(3)
                    Text("Locked-in").tag(5)
                }
                .disabled(!crownControlEnabled)

                Toggle(isOn: $invertCrown) {
                    Label("Invert Crown", systemImage: "digitalcrown.horizontal.arrow.counterclockwise")
                        .font(.system(size: 15))
                }
                .disabled(!crownControlEnabled)
            } footer: {
                Text(crownFooterText)
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
