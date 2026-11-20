import SwiftUI

// MARK: - iPhone App Entry Point
@main
struct DeckApp: App {
    @StateObject private var connectionManager = iPhoneConnectionManager()
    @StateObject private var presentationTimer = PresentationTimer()
    @State private var subscriptionManager = SubscriptionManager()
    @AppStorage(iPhoneConnectionManager.onboardingCompletedKey) private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    SubscriptionGateView(connectionManager: connectionManager, timer: presentationTimer)
                } else {
                    OnboardingView {
                        withAnimation { hasCompletedOnboarding = true }
                        // Starts discovery, which shows the Local Network prompt
                        // the last onboarding page just told them to Allow.
                        connectionManager.beginDiscovery()
                    }
                }
            }
            .environment(subscriptionManager)
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Subscription Gate View
/// Gates the app behind subscription/trial status
struct SubscriptionGateView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var connectionManager: iPhoneConnectionManager
    @ObservedObject var timer: PresentationTimer
    @State private var showPaywall = false

    var body: some View {
        Group {
            switch subscriptionManager.status {
            case .notDetermined:
                // Loading state
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

            case .trial, .subscribed:
                // Full access
                ContentView(connectionManager: connectionManager, timer: timer)
                    .overlay(alignment: .top) {
                        if let days = subscriptionManager.trialDaysRemaining {
                            TrialBannerView(daysRemaining: days) {
                                showPaywall = true
                            }
                        }
                    }

            case .expired:
                // Paywall
                PaywallView()
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh subscription status when app becomes active
            // Catches purchases made outside the app or subscription renewals
            if newPhase == .active {
                Task {
                    await subscriptionManager.updateSubscriptionStatus()
                }
                // Restart Mac discovery: recovers a browser that went stale in
                // the background or was started before the Local Network
                // permission alert was answered (first launch).
                connectionManager.handleAppBecameActive()
            }
        }
    }
}

// MARK: - Trial Banner View
/// Shows remaining trial days with upgrade prompt
struct TrialBannerView: View {
    let daysRemaining: Int
    let onUpgrade: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundStyle(.orange)

            Text("Trial: \(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left")
                .font(.subheadline.weight(.medium))

            Spacer()

            Button("Upgrade") {
                onUpgrade()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.orange, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @ObservedObject var connectionManager: iPhoneConnectionManager
    @ObservedObject var timer: PresentationTimer

    /// Debug builds can launch straight into the remote without a Mac
    /// (`-previewRemote`), for layout work in the simulator.
    private static var previewRemote: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-previewRemote")
        #else
        false
        #endif
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black, Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if connectionManager.isConnected || Self.previewRemote {
                ArcRemoteView(connectionManager: connectionManager, timer: timer)
            } else {
                ConnectionView(connectionManager: connectionManager)
            }
        }
    }
}

// MARK: - Connection View
/// The "get connected" screen. Shows a picture of where things stand
/// (iPhone ⟷ Mac), one plain-language headline, and exactly the next thing to
/// do. Troubleshooting appears on its own when something takes too long.
struct ConnectionView: View {
    @ObservedObject var connectionManager: iPhoneConnectionManager
    @State private var showHelp = false
    @State private var isConnectingSlow = false

    private enum Phase: Equatable {
        case denied
        case searching
        case found
        case connecting(String)
        case failed(String)
    }

    private var phase: Phase {
        if connectionManager.localNetworkDenied { return .denied }
        if let name = connectionManager.connectingMacName { return .connecting(name) }
        if let name = connectionManager.failedMacName { return .failed(name) }
        if !connectionManager.availableMacs.isEmpty { return .found }
        return .searching
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Image("DeckLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                Text("Deck")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showHelp = true
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 28) {
                    DevicePairIllustration(state: illustrationState)
                        .padding(.top, 32)

                    VStack(spacing: 10) {
                        Text(headline)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text(subheadline)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .animation(.easeInOut(duration: 0.2), value: phase)

                    actionArea
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .sheet(isPresented: $showHelp) {
            HelpSheet(connectionManager: connectionManager)
        }
        // If connecting stalls, nudge the user toward the usual culprit (the Mac).
        .task(id: connectionManager.connectingMacName) {
            isConnectingSlow = false
            guard connectionManager.connectingMacName != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { withAnimation { isConnectingSlow = true } }
        }
    }

    // MARK: Copy

    private var illustrationState: DevicePairIllustration.LinkState {
        switch phase {
        case .denied, .failed: return .failed
        case .searching, .found: return .searching
        case .connecting: return .connecting
        }
    }

    private var headline: String {
        switch phase {
        case .denied: return "Deck can't look for your Mac"
        case .searching: return "Looking for your Mac…"
        case .found: return "Tap your Mac to connect"
        case .connecting(let name): return "Connecting to \(name)…"
        case .failed: return "Couldn't connect"
        }
    }

    private var subheadline: String {
        switch phase {
        case .denied:
            return "Your iPhone is blocking Deck from your Wi-Fi network. It's a quick fix in Settings."
        case .searching:
            return connectionManager.isSearchTakingLong
                ? "This is taking longer than usual. Check these things:"
                : "Make sure Deck is open on your Mac and both are on the same Wi-Fi."
        case .found:
            return "We found your Mac. Choose it below."
        case .connecting:
            return "This usually takes a few seconds."
        case .failed(let name):
            return "\(name) didn't answer. This is usually easy to fix:"
        }
    }

    // MARK: Actions

    @ViewBuilder
    private var actionArea: some View {
        switch phase {
        case .denied:
            LocalNetworkDeniedCard()

        case .searching:
            if connectionManager.isSearchTakingLong {
                ChecklistCard(items: Self.searchChecklist)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, 8)
                NoMacAppLink()
            }

        case .found:
            VStack(spacing: 12) {
                ForEach(Array(connectionManager.availableMacs.enumerated()), id: \.element.displayName) { index, mac in
                    MacRow(name: mac.displayName, isSuggested: index == 0) {
                        connectionManager.connectTo(mac)
                    }
                }
            }

        case .connecting:
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                if isConnectingSlow {
                    ChecklistCard(items: Self.connectingChecklist)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                Button("Cancel") {
                    connectionManager.cancelConnecting()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            }

        case .failed:
            VStack(spacing: 16) {
                ChecklistCard(items: Self.connectingChecklist)
                PrimaryButton(title: "Try Again", systemImage: "arrow.clockwise") {
                    connectionManager.retryFailedConnection()
                }
            }
        }
    }

    // MARK: Checklists

    private static let searchChecklist: [ChecklistCard.Item] = [
        .init(icon: "macbook", title: "Deck is open on your Mac",
              detail: "Look for the Deck icon at the top-right of your Mac's screen. If it's not there, open Deck from Applications."),
        .init(icon: "wifi", title: "Same Wi-Fi on both",
              detail: "Your iPhone and Mac must be on the same Wi-Fi. Hotel or guest Wi-Fi can block devices — try your iPhone's Personal Hotspot instead."),
        .init(icon: "lock.shield", title: "Turn off VPN",
              detail: "A VPN on either device can hide them from each other."),
        .init(icon: "arrow.down.circle", title: "Don't have Deck on your Mac?",
              detail: "Download it free from \(DeckLinks.macDownloadDisplay).")
    ]

    private static let connectingChecklist: [ChecklistCard.Item] = [
        .init(icon: "macbook", title: "Look at your Mac",
              detail: "If your Mac asks to let Deck find devices on your network, click Allow."),
        .init(icon: "gearshape", title: "Allow Local Network on the Mac",
              detail: "On your Mac: System Settings → Privacy & Security → Local Network → turn on Deck."),
        .init(icon: "arrow.clockwise", title: "Restart Deck on your Mac",
              detail: "Click the Deck icon at the top of your Mac's screen, choose Quit, then open Deck again.")
    ]
}

// MARK: - Connection Building Blocks

/// One tappable Mac. The first one gets a gentle pulse so it's obvious what to tap.
private struct MacRow: View {
    let name: String
    let isSuggested: Bool
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "macbook")
                    .font(.title2)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body.weight(.semibold))
                    Text("Tap to connect")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.blue.opacity(isSuggested ? (pulse ? 0.9 : 0.3) : 0.1), lineWidth: 2)
            )
        }
        .buttonStyle(GlassButtonStyle())
        .onAppear {
            guard isSuggested else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// A short list of "check this" items, each with an icon and one sentence.
struct ChecklistCard: View {
    struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: item.icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.08)))
    }
}

/// Small "I don't have it on my Mac yet" escape hatch shown while searching.
private struct NoMacAppLink: View {
    var body: some View {
        ShareLink(item: DeckLinks.macDownload) {
            Label("Don't have Deck on your Mac yet?", systemImage: "arrow.down.circle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.blue)
        }
        .padding(.top, 8)
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(GlassButtonStyle())
    }
}

// MARK: - Local Network Denied Card
/// Shown when iOS has denied Local Network access, which makes Mac discovery
/// impossible. Walks the user through the exact switch to flip.
struct LocalNetworkDeniedCard: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HintRow(icon: "1.circle.fill", tint: .orange, text: "Tap **Open Settings** below.")
            HintRow(icon: "2.circle.fill", tint: .orange, text: "Turn on the **Local Network** switch.")
            HintRow(icon: "3.circle.fill", tint: .orange, text: "Come back to Deck. It will find your Mac automatically.")

            PrimaryButton(title: "Open Settings", systemImage: "gearshape") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.orange.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Help Sheet
/// Plain-language setup help. Technical diagnostics live at the very bottom,
/// for when someone is talking to support.
struct HelpSheet: View {
    @ObservedObject var connectionManager: iPhoneConnectionManager
    @Environment(\.dismiss) private var dismiss
    @State private var showDiagnostics = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HelpStep(number: 1, title: "Install Deck on your Mac",
                             detail: "It's free. Download it on your Mac from \(DeckLinks.macDownloadDisplay).")
                    HelpStep(number: 2, title: "Open Deck on your Mac",
                             detail: "A small Deck icon appears at the top-right of your Mac's screen. Click it — it should say it's waiting for your iPhone.")
                    HelpStep(number: 3, title: "Allow Deck to change slides",
                             detail: "The first time, your Mac asks you to allow Deck in Accessibility settings. Turn on the switch next to Deck.")
                    HelpStep(number: 4, title: "Connect from your iPhone",
                             detail: "Keep both on the same Wi-Fi, open Deck on your iPhone, and tap your Mac's name.")
                } header: {
                    Text("Setting up")
                }

                Section {
                    ShareLink(item: DeckLinks.macDownload) {
                        Label("Send Mac Download Link", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    HelpTip(icon: "wifi.exclamationmark", title: "On hotel, school or office Wi-Fi?",
                            detail: "These networks often block devices from seeing each other. Turn on Personal Hotspot on your iPhone and join it from your Mac.")
                    HelpTip(icon: "lock.shield", title: "Using a VPN?",
                            detail: "Turn it off on both devices while presenting.")
                    HelpTip(icon: "hand.raised", title: "Slides don't change?",
                            detail: "On your Mac, click the Deck icon at the top of the screen. If it shows a warning, click it and follow the steps. Then click on your slideshow window once so it's in front.")
                } header: {
                    Text("Common problems")
                }

                Section {
                    Button {
                        showDiagnostics = true
                    } label: {
                        Label("Connection Diagnostics", systemImage: "stethoscope")
                    }
                } footer: {
                    Text("Technical details to share if you contact support.")
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showDiagnostics) {
                ConnectionDebugView(connectionManager: connectionManager)
            }
        }
    }
}

private struct HelpStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.black)
                .frame(width: 26, height: 26)
                .background(.white, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HelpTip: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - First-Use Remote Tips
/// Shown once, the first time someone connects, so they know which button
/// does what before they're in front of an audience.
struct RemoteTipsOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 18) {
                Label("You're connected!", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.green)

                HintRow(icon: "play.rectangle", tint: .white,
                        text: "On your Mac, start your slideshow and click on it once so it's in front.")
                HintRow(icon: "chevron.right", tint: .white,
                        text: "Tap the **big white button** for the next slide.")
                HintRow(icon: "chevron.left", tint: .white,
                        text: "Tap the **arrow below it** to go back.")
                HintRow(icon: "cursorarrow.motionlines", tint: .white,
                        text: "**Hold** the pointer button and aim your iPhone to move the Mac's cursor. Tap it to click.")
                HintRow(icon: "timer", tint: .white,
                        text: "Press **▶︎** on the timer to track your talk. Your iPhone will gently buzz to keep you on time.")
                HintRow(icon: "applewatch", tint: .white,
                        text: "Have an Apple Watch? Open Deck on it to change slides from your wrist.")

                PrimaryButton(title: "Got It", action: onDismiss)
                    .padding(.top, 4)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 20)
        }
        .transition(.opacity)
    }
}

// MARK: - Glass Button Style
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Status Bar
struct StatusBarView: View {
    let macName: String
    let onDisconnect: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Controlling \(macName)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Disconnect", action: onDisconnect)
                .font(.subheadline)
                .foregroundStyle(.red.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Remote Settings View
struct RemoteSettingsView: View {
    @ObservedObject var timer: PresentationTimer
    @AppStorage(Handedness.storageKey) private var hand: Handedness = .right
    @AppStorage(PointerController.sensitivityKey) private var pointerSensitivity = 1.0
    @AppStorage(ArcRemoteView.nextClicksKey) private var nextClicks = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                // Handedness
                Section {
                    Picker("Holding Hand", selection: $hand) {
                        ForEach(Handedness.allCases) { hand in
                            Text(hand.label).tag(hand)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Holding Hand")
                } footer: {
                    Text("Controls arc around the thumb of the hand holding the phone")
                }

                // Next button behavior
                Section {
                    Toggle("Next Button Left-Clicks", isOn: $nextClicks)
                } header: {
                    Text("Next Button")
                } footer: {
                    Text("Sends a left click at the Mac's cursor instead of the right arrow key. Use it for slides or apps that advance on click.")
                }

                // Pointer
                Section {
                    Slider(value: $pointerSensitivity, in: 0.4...2.5) {
                        Text("Pointer Speed")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise")
                    } maximumValueLabel: {
                        Image(systemName: "hare")
                    }
                } header: {
                    Text("Pointer Speed")
                } footer: {
                    Text("Hold the pointer button and aim the phone to move the Mac cursor. Tap it to click.")
                }

                // Vibration Toggle
                Section {
                    Toggle("Haptic Alerts", isOn: $timer.config.isEnabled)
                } header: {
                    Text("Timer")
                } footer: {
                    Text("Receive haptic feedback at intervals during your presentation")
                }

                // Vibration Interval
                Section("Interval") {
                    ForEach(TimerConfig.presets, id: \.interval) { preset in
                        Button {
                            timer.config.vibrationInterval = preset.interval
                        } label: {
                            HStack {
                                Text(preset.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if timer.config.vibrationInterval == preset.interval {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                // Duration
                Section {
                    ForEach(TimerConfig.durationPresets, id: \.name) { preset in
                        Button {
                            timer.config.totalDuration = preset.duration
                        } label: {
                            HStack {
                                Text(preset.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if timer.config.totalDuration == preset.duration {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Duration")
                } footer: {
                    Text("Set total duration for progress tracking and overtime alerts")
                }

                // Test
                Section {
                    Button {
                        timer.testVibration()
                    } label: {
                        Label("Test Haptic", systemImage: "waveform")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView(connectionManager: iPhoneConnectionManager(), timer: PresentationTimer())
}
