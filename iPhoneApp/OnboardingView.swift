import SwiftUI

// MARK: - Shared Links
enum DeckLinks {
    /// Where people download the free Mac companion app.
    // Safe force-unwrap: hardcoded compile-time constant URL
    static let macDownload = URL(string: "https://github.com/douinc/deck/releases/latest")!
    static let macDownloadDisplay = "github.com/douinc/deck"
}

// MARK: - First-Launch Onboarding
/// A short, picture-first walkthrough for people who have never used a
/// presentation remote app. It explains the two-device setup before asking
/// for anything, and only triggers the Local Network prompt on the last page,
/// right after telling the user what it is and that they should tap "Allow".
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    private let pageCount = 3

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    WelcomePage().tag(0)
                    MacAppPage().tag(1)
                    PermissionPage().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                PageDots(count: pageCount, current: page)
                    .padding(.bottom, 20)

                Button {
                    if page < pageCount - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(primaryTitle)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
    }

    private var primaryTitle: String {
        switch page {
        case 0: return "Get Started"
        case 1: return "Deck Is on My Mac"
        default: return "Continue"
        }
    }
}

// MARK: - Pages

private struct WelcomePage: View {
    var body: some View {
        OnboardingPage(
            title: "Your iPhone is now a clicker",
            message: "Change slides on your Mac from anywhere in the room. Works with Keynote, PowerPoint, Google Slides and more."
        ) {
            DevicePairIllustration(state: .connected)
        }
    }
}

private struct MacAppPage: View {
    var body: some View {
        OnboardingPage(
            title: "Get Deck for your Mac",
            message: "Deck needs a small free helper app on the Mac you present from. It sits quietly at the top of your Mac's screen."
        ) {
            VStack(spacing: 20) {
                MenuBarIllustration()

                VStack(alignment: .leading, spacing: 14) {
                    HintRow(icon: "arrow.down.circle.fill", tint: .blue,
                            text: "On your Mac, go to \(DeckLinks.macDownloadDisplay) and download Deck.")
                    HintRow(icon: "hand.point.up.left.fill", tint: .blue,
                            text: "Open it, then look for the Deck icon at the top-right of your Mac's screen.")
                }

                ShareLink(item: DeckLinks.macDownload) {
                    Label("Send the Download Link to My Mac", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PermissionPage: View {
    var body: some View {
        OnboardingPage(
            title: "One quick permission",
            message: "Next, your iPhone will ask to find devices on your network. This is how it finds your Mac — nothing leaves your Wi-Fi."
        ) {
            VStack(spacing: 16) {
                SystemAlertMock()
                HintRow(icon: "hand.tap.fill", tint: .green, text: "When you see this, tap **Allow**.")
            }
        }
    }
}

// MARK: - Page Layout

private struct OnboardingPage<Visual: View>: View {
    let title: String
    let message: String
    @ViewBuilder let visual: () -> Visual

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)
                visual()
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.white : Color.white.opacity(0.25))
                    .frame(width: index == current ? 20 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: current)
    }
}

// MARK: - Reusable Visuals

/// iPhone ⟷ Mac picture with a link between them that reflects the current
/// connection state. Used in onboarding and on the connection screen.
struct DevicePairIllustration: View {
    enum LinkState { case idle, searching, connecting, connected, failed }
    let state: LinkState

    var body: some View {
        HStack(spacing: 18) {
            deviceBadge("iphone", highlighted: true)
            link
                .frame(width: 56)
            deviceBadge("macbook", highlighted: state == .connected || state == .connecting)
        }
        .padding(.vertical, 8)
    }

    private func deviceBadge(_ symbol: String, highlighted: Bool) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 96, height: 96)
                .overlay(Circle().strokeBorder(highlighted ? Color.white.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1))
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(highlighted ? .white : .secondary)
        }
    }

    @ViewBuilder
    private var link: some View {
        switch state {
        case .idle:
            Image(systemName: "ellipsis")
                .font(.title.weight(.bold))
                .foregroundStyle(.tertiary)
        case .searching, .connecting:
            Image(systemName: "ellipsis")
                .font(.title.weight(.bold))
                .foregroundStyle(state == .connecting ? .blue : .white)
                .symbolEffect(.variableColor.iterative.reversing)
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .foregroundStyle(.orange)
        }
    }
}

/// A sketch of the Mac's menu bar with the Deck icon called out, so people
/// know what to look for after installing the Mac app.
struct MenuBarIllustration: View {
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                Spacer()
                Image(systemName: "wifi")
                Image(systemName: "battery.75percent")
                ZStack {
                    Circle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: 30, height: 30)
                    Image("DeckLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
                Text("9:41")
                    .font(.caption.weight(.medium))
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()
                Label("Deck on your Mac", systemImage: "arrow.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .padding(.trailing, 42)
            }
        }
    }
}

/// A look-alike of the iOS Local Network alert with "Allow" highlighted, so
/// the real prompt feels familiar instead of alarming.
private struct SystemAlertMock: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("“Deck” Would Like to Find and Connect to Devices on Your Local Network")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Deck needs local network access to find and connect to your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)

            Divider()
            HStack(spacing: 0) {
                Text("Don't Allow")
                    .font(.body)
                    .foregroundStyle(.blue.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                Divider().frame(height: 44)
                Text("Allow")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.green, lineWidth: 2).padding(4))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: 290)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.1)))
    }
}

/// Icon + one plain-language sentence. The basic unit of every hint.
struct HintRow: View {
    let icon: String
    var tint: Color = .secondary
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
