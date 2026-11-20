import SwiftUI

// MARK: - Handedness
enum Handedness: String, CaseIterable, Identifiable {
    case left, right

    static let storageKey = "handedness"

    var id: String { rawValue }
    var label: String { self == .left ? "Left" : "Right" }
}

// MARK: - Arc Layout
/// Geometry for controls laid out on arcs swept by the holding hand's thumb.
///
/// The pivot sits just outside the bottom corner on the holding side, roughly
/// where the base of the thumb rests. Angles are measured at the pivot from the
/// bottom edge: 0° reaches straight across the screen, 90° straight up.
struct ArcLayout {
    let size: CGSize
    let hand: Handedness

    /// Scale reference: screen width, capped so the arcs fit short screens
    var unit: CGFloat { min(size.width, size.height * 0.55) }

    var pivot: CGPoint {
        CGPoint(x: hand == .right ? size.width + unit * 0.05 : -unit * 0.05, y: size.height)
    }

    var innerRadius: CGFloat { unit * 0.70 }   // Primary row: thumb at rest
    var outerRadius: CGFloat { unit * 1.08 }   // Secondary row: thumb extended
    var timerRadius: CGFloat { unit * 1.32 }   // Progress arc, above both rows

    var primaryDiameter: CGFloat { unit * 0.235 }
    var secondaryDiameter: CGFloat { unit * 0.175 }

    func point(radius: CGFloat, degrees: Double) -> CGPoint {
        let angle = degrees * .pi / 180
        let across = radius * cos(angle)
        return CGPoint(
            x: hand == .right ? pivot.x - across : pivot.x + across,
            y: pivot.y - radius * sin(angle)
        )
    }

    /// Arc centered on the pivot. Starts at the far (low-angle) end.
    func arc(radius: CGFloat, from start: Double, to end: Double) -> Path {
        let steps = 48
        var path = Path()
        for step in 0...steps {
            let degrees = start + (end - start) * Double(step) / Double(steps)
            let p = point(radius: radius, degrees: degrees)
            if step == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }
}

// MARK: - Arc Remote View
struct ArcRemoteView: View {
    @ObservedObject var connectionManager: iPhoneConnectionManager
    @ObservedObject var timer: PresentationTimer

    /// When on, the Next button left-clicks instead of sending the right arrow key
    static let nextClicksKey = "nextButtonClicks"

    @AppStorage(Handedness.storageKey) private var hand: Handedness = .right
    @AppStorage(ArcRemoteView.nextClicksKey) private var nextClicks = false
    @StateObject private var pointer = PointerController()
    @State private var showDisconnectConfirm = false
    @State private var showSettings = false
    @State private var pickingMinutes: Int?
    @AppStorage("hasSeenRemoteTips") private var hasSeenRemoteTips = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            StatusBarView(
                macName: connectionManager.connectedMac?.displayName ?? "Connected",
                onDisconnect: { showDisconnectConfirm = true }
            )

            GeometryReader { geometry in
                let layout = ArcLayout(size: geometry.size, hand: hand)

                ZStack {
                    TimerArc(layout: layout, timer: timer, pickingMinutes: $pickingMinutes)

                    TimerReadout(timer: timer, pointerActive: pointer.isActive, pickingMinutes: pickingMinutes, alignTrailing: hand == .left)
                        .padding(.horizontal, 24)
                        .padding(.top, 52)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: hand == .right ? .topLeading : .topTrailing)

                    controls(layout)
                }
            }
        }
        .background {
            // Soft light from the holding corner, so the arcs read as radiating from the thumb
            RadialGradient(
                colors: [.white.opacity(0.09), .clear],
                center: hand == .right ? .bottomTrailing : .bottomLeading,
                startRadius: 0,
                endRadius: 560
            )
            .ignoresSafeArea()
        }
        .overlay {
            if !hasSeenRemoteTips {
                RemoteTipsOverlay {
                    withAnimation { hasSeenRemoteTips = true }
                }
            }
        }
        .animation(.spring(duration: 0.4), value: hand)
        .animation(.easeOut(duration: 0.15), value: pointer.isActive)
        .alert("Disconnect?", isPresented: $showDisconnectConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                timer.pause()
                connectionManager.disconnect()
            }
        } message: {
            Text("Your iPhone will stop controlling \(connectionManager.connectedMac?.displayName ?? "this Mac"). You can reconnect anytime.")
        }
        .sheet(isPresented: $showSettings) {
            RemoteSettingsView(timer: timer)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            pointer.send = { [weak connectionManager] in connectionManager?.sendPointer($0) }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            pointer.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pointer.cancel() }
        }
    }

    @ViewBuilder
    private func controls(_ layout: ArcLayout) -> some View {
        let small = layout.secondaryDiameter
        let dimmed = pointer.isActive

        // Inner arc — slide control and pointer, under the resting thumb
        Group {
            ArcButton(systemImage: "chevron.left", label: "Previous", diameter: small) {
                connectionManager.previousSlide()
            }
            .position(layout.point(radius: layout.innerRadius, degrees: 23))

            ArcButton(systemImage: "chevron.right", label: "Next", diameter: layout.primaryDiameter, prominent: true) {
                if nextClicks { connectionManager.click() } else { connectionManager.nextSlide() }
            }
            .position(layout.point(radius: layout.innerRadius, degrees: 49))
        }
        .opacity(dimmed ? 0.3 : 1)

        PointerButton(pointer: pointer, diameter: small)
            .position(layout.point(radius: layout.innerRadius, degrees: 75))

        // Outer arc — timer and settings, a thumb stretch away
        Group {
            ArcButton(systemImage: "arrow.counterclockwise", label: "Reset timer", diameter: small) {
                timer.reset()
            }
            .position(layout.point(radius: layout.outerRadius, degrees: 39))

            ArcButton(
                systemImage: timer.isRunning ? "pause.fill" : "play.fill",
                label: timer.isRunning ? "Pause timer" : "Start timer",
                diameter: small,
                tint: timer.isRunning ? .orange : .green
            ) {
                timer.toggle()
            }
            .position(layout.point(radius: layout.outerRadius, degrees: 58))

            ArcButton(systemImage: "gearshape", label: "Settings", diameter: small) {
                showSettings = true
            }
            .position(layout.point(radius: layout.outerRadius, degrees: 77))
        }
        .opacity(dimmed ? 0.3 : 1)
    }
}

// MARK: - Arc Button
struct ArcButton: View {
    let systemImage: String
    let label: String
    let diameter: CGFloat
    var prominent = false
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * (prominent ? 0.38 : 0.34), weight: prominent ? .regular : .medium))
                .foregroundStyle(prominent ? Color.black : tint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: diameter, height: diameter)
                .background {
                    if prominent {
                        Circle().fill(.white.opacity(0.94))
                    } else {
                        Circle().fill(.ultraThinMaterial)
                    }
                }
                .overlay(Circle().strokeBorder(.white.opacity(prominent ? 0 : 0.14), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(ArcPressStyle())
        .accessibilityLabel(label)
    }
}

struct ArcPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Pointer Button
/// Hold to move the Mac cursor by pointing the phone; tap to click.
struct PointerButton: View {
    @ObservedObject var pointer: PointerController
    let diameter: CGFloat

    // GestureState resets on cancellation too, so a hold can't get stuck on
    @GestureState private var isHeld = false

    var body: some View {
        Image(systemName: "cursorarrow.motionlines")
            .font(.system(size: diameter * 0.34, weight: .medium))
            .foregroundStyle(pointer.isActive ? Color.black : Color.white)
            .frame(width: diameter, height: diameter)
            .background {
                if pointer.isActive {
                    Circle().fill(.white)
                } else {
                    Circle().fill(.ultraThinMaterial)
                }
            }
            .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
            .scaleEffect(pointer.isActive ? 1.15 : 1.0)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isHeld) { _, state, _ in state = true }
            )
            .onChange(of: isHeld) { _, held in
                if held { pointer.pressBegan() } else { pointer.pressEnded() }
            }
            .accessibilityLabel("Pointer")
            .accessibilityHint("Hold and point the phone to move the cursor. Tap to click.")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Timer Arc
/// Time gauge on an arc concentric with the button rows.
/// While the timer is stopped, sliding along the arc sets the limit. The bar
/// stays where it was set and drains as the talk counts down. With no limit
/// it sweeps once a minute instead.
struct TimerArc: View {
    let layout: ArcLayout
    @ObservedObject var timer: PresentationTimer
    /// Minutes being picked mid-drag (0 = no limit), nil when not dragging
    @Binding var pickingMinutes: Int?

    static let maxMinutes = 30

    private let startDegrees = 41.0   // Keeps the far end on-screen
    private let endDegrees = 82.0
    private let tick = UISelectionFeedbackGenerator()

    var body: some View {
        let track = layout.arc(radius: layout.timerRadius, from: startDegrees, to: endDegrees)
        let style = StrokeStyle(lineWidth: pickingMinutes == nil ? 5 : 9, lineCap: .round)

        ZStack {
            track.stroke(isOverTime ? Color.red.opacity(0.4) : Color.white.opacity(0.1), style: style)

            track
                .trim(from: 0, to: fraction)
                .stroke(color, style: style)
                .animation(pickingMinutes == nil ? .linear(duration: fraction == 0 ? 0.2 : 1.0) : nil, value: fraction)
        }
        .animation(.easeOut(duration: 0.15), value: pickingMinutes == nil)
        // Generous touch band around the thin stroke
        .contentShape(track.strokedPath(StrokeStyle(lineWidth: 56, lineCap: .round)))
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    let minutes = minutes(at: value.location)
                    if minutes != pickingMinutes {
                        tick.selectionChanged()
                        pickingMinutes = minutes
                    }
                }
                .onEnded { value in
                    let minutes = minutes(at: value.location)
                    timer.config.totalDuration = minutes == 0 ? nil : TimeInterval(minutes * 60)
                    pickingMinutes = nil
                }
        )
        // Locked while running so a stray thumb can't change the limit mid-talk
        .allowsHitTesting(!timer.isRunning)
    }

    private func minutes(at location: CGPoint) -> Int {
        let across = layout.hand == .right ? layout.pivot.x - location.x : location.x - layout.pivot.x
        let degrees = atan2(layout.pivot.y - location.y, across) * 180 / .pi
        let fraction = min(max((degrees - startDegrees) / (endDegrees - startDegrees), 0), 1)
        return Int((fraction * Double(Self.maxMinutes)).rounded())
    }

    private var fraction: Double {
        if let pickingMinutes { return Double(pickingMinutes) / Double(Self.maxMinutes) }
        // Same scale as the drag, so the bar rests exactly where it was set
        if let remaining = timer.remainingTime {
            return min(remaining / TimeInterval(Self.maxMinutes * 60), 1)
        }
        return timer.elapsedTime.truncatingRemainder(dividingBy: 60) / 60
    }

    private var isOverTime: Bool {
        guard pickingMinutes == nil, let total = timer.config.totalDuration else { return false }
        return timer.elapsedTime >= total
    }

    private var color: Color {
        if pickingMinutes != nil { return .white.opacity(0.85) }
        guard let progress = timer.progress else { return .white.opacity(0.55) }
        if progress >= 1.0 { return .red }
        if progress >= 0.9 { return .orange }
        if progress >= 0.75 { return .yellow }
        return .green
    }
}

// MARK: - Timer Readout
struct TimerReadout: View {
    @ObservedObject var timer: PresentationTimer
    let pointerActive: Bool
    /// Minutes being picked on the arc (0 = no limit), nil when not dragging
    let pickingMinutes: Int?
    let alignTrailing: Bool

    var body: some View {
        VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 2) {
            Text(timeText)
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timeColor)
                .contentTransition(.numericText())
                .animation(.default, value: timeText)

            Text(caption)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        .opacity(timer.isRunning || pointerActive || pickingMinutes != nil ? 1 : 0.6)
        .accessibilityElement(children: .combine)
    }

    private var timeText: String {
        if let pickingMinutes { return String(format: "%02d:00", pickingMinutes) }
        guard let total = timer.config.totalDuration else { return timer.formattedTime }

        // With a limit set the readout counts down, then counts up the overrun
        let remaining = Int(total - timer.elapsedTime)
        let seconds = abs(remaining)
        return String(format: "%@%02d:%02d", remaining < 0 ? "+" : "", seconds / 60, seconds % 60)
    }

    private var caption: String {
        if let pickingMinutes { return pickingMinutes == 0 ? "No limit" : "Time limit" }
        if pointerActive { return "Pointer active" }
        if let total = timer.config.totalDuration {
            let limit = "\(Int(total) / 60) min"
            if timer.elapsedTime >= total { return "Over \(limit)" }
            if timer.isRunning { return "Left of \(limit)" }
            return timer.elapsedTime > 0 ? "Paused · \(limit)" : "\(limit) limit"
        }
        if timer.isRunning { return "Elapsed" }
        if timer.elapsedTime > 0 { return "Paused" }
        return "Slide the arc to set a limit"
    }

    private var timeColor: Color {
        if pickingMinutes != nil { return .white }
        if let total = timer.config.totalDuration {
            if timer.elapsedTime >= total { return .red }
            if timer.elapsedTime >= total * 0.9 { return .orange }
        }
        return .white
    }
}

// MARK: - Preview
#Preview("Right hand") {
    ArcRemoteView(connectionManager: iPhoneConnectionManager(), timer: PresentationTimer())
        .background(Color.black)
        .preferredColorScheme(.dark)
}
