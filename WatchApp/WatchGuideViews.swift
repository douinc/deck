import SwiftUI
import WatchKit

// MARK: - Connect Guide
/// Shown instead of the controls while the iPhone isn't connected to a Mac.
/// The watch only talks to the iPhone, so the fix is always on the phone —
/// this screen says so in plain words. The controls appear automatically
/// as soon as the iPhone connects.
struct WatchConnectGuideView: View {
    @EnvironmentObject var connectionManager: WatchConnectionManager
    let onShowControls: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "applewatch")
                    Image(systemName: "ellipsis")
                        .symbolEffect(.variableColor.iterative.reversing)
                    Image(systemName: "iphone")
                    Image(systemName: "ellipsis")
                        .symbolEffect(.variableColor.iterative.reversing)
                    Image(systemName: "macbook")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                .padding(.top, 4)

                Text("Connect your iPhone first")
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    GuideStep(number: 1, text: "Open Deck on your iPhone")
                    GuideStep(number: 2, text: "Tap your Mac's name to connect")
                    GuideStep(number: 3, text: "Come back here — your controls appear by themselves")
                }

                Button("Show Controls", action: onShowControls)
                    .font(.system(size: 14))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct GuideStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.white))
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - First-Run Tips
/// A few swipeable cards that explain each way to change slides, shown once.
/// Reopen anytime from Settings → "Show Tips".
struct WatchTipsView: View {
    @AppStorage("gestureMode") private var gestureMode = "doubleTap"
    let onDone: () -> Void

    private struct Tip: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let text: String
    }

    private var tips: [Tip] {
        var list = [
            Tip(icon: "chevron.right.circle.fill", title: "Next slide",
                text: "Tap the big blue button."),
        ]
        if gestureMode == "doubleTap" {
            list.append(Tip(icon: "hand.tap.fill", title: "Hands-free",
                            text: "Tap your index finger and thumb together twice. Works with your wrist raised (Series 9 or newer)."))
        } else {
            list.append(Tip(icon: "hand.wave.fill", title: "Flick your wrist",
                            text: "Flick forward for next, backward for previous. Tap the hand icon to turn this on or off."))
        }
        list.append(contentsOf: [
            Tip(icon: "digitalcrown.horizontal.arrow.clockwise.fill", title: "Turn the Crown",
                text: "Turn it one click to move one slide forward or back."),
            Tip(icon: "timer", title: "Timer",
                text: "Tap the time to start or pause. Press and hold to reset."),
        ])
        return list
    }

    var body: some View {
        TabView {
            ForEach(tips) { tip in
                TipCard(icon: tip.icon, title: tip.title, text: tip.text)
            }
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
                Text("You're ready!")
                    .font(.system(size: 16, weight: .semibold))
                Button("Start", action: onDone)
            }
        }
        .tabViewStyle(.verticalPage)
    }
}

private struct TipCard: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.blue)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 6)
    }
}
