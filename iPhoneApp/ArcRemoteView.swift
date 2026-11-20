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

    // Golden spacing: each step outward from the thumb is the previous one
    // divided by φ — inner row → outer row → timer arc → readout.
    static let phi: CGFloat = 1.618034
    var timerRadius: CGFloat { outerRadius + (outerRadius - innerRadius) / Self.phi }
    var readoutRadius: CGFloat { timerRadius + (timerRadius - outerRadius) / Self.phi }

    /// Side margin shared by the readout and both ends of the timer arc
    let margin: CGFloat = 24

    /// The timer arc runs edge to edge: these are the angles where it meets the margins
    var timerStartDegrees: Double {
        let across = size.width + unit * 0.05 - margin
        return max(25, acos(min(1, Double(across / timerRadius))) * 180 / .pi)
    }
    var timerEndDegrees: Double {
        let across = unit * 0.05 + margin
        return acos(min(1, Double(across / timerRadius))) * 180 / .pi
    }

    /// Top-left origin for a readout of the given size, placed so its corner
    /// nearest the arc rests on the readout radius.
    func readoutOrigin(for readout: CGSize) -> CGPoint {
        let across = size.width + unit * 0.05 - margin - readout.width   // Inner corner, from the pivot
        let reach = readoutRadius
        let up = across < reach ? (reach * reach - across * across).squareRoot() : 0
        let top = max(16, pivot.y - up - readout.height)
        return CGPoint(x: hand == .right ? margin : size.width - margin - readout.width, y: top)
    }

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

    /// Hand- and device-independent position: distance from the pivot in units,
    /// x across the screen and y up. Saved layouts use this, so they mirror
    /// with the holding hand and scale to other screen sizes.
    func normalized(_ point: CGPoint) -> CGPoint {
        let across = hand == .right ? pivot.x - point.x : point.x - pivot.x
        return CGPoint(x: across / unit, y: (pivot.y - point.y) / unit)
    }

    func point(normalized: CGPoint) -> CGPoint {
        let across = normalized.x * unit
        return CGPoint(
            x: hand == .right ? pivot.x - across : pivot.x + across,
            y: pivot.y - normalized.y * unit
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

// MARK: - Arc Controls
enum ArcControl: String, CaseIterable, Identifiable {
    case previous, next, pointer, resetTimer, toggleTimer, settings

    static let positionsKey = "arcButtonPositions"

    var id: String { rawValue }

    /// Inner arc holds slide control and the pointer, under the resting thumb;
    /// the outer arc holds timer and settings, a thumb stretch away.
    var isInner: Bool { self == .previous || self == .next || self == .pointer }

    var defaultDegrees: Double {
        switch self {
        case .previous: return 23
        case .next: return 49
        case .pointer: return 75
        case .resetTimer: return 39
        case .toggleTimer: return 58
        case .settings: return 77
        }
    }

    static func loadPositions() -> [ArcControl: CGPoint] {
        guard let stored = UserDefaults.standard.dictionary(forKey: positionsKey) as? [String: [Double]] else { return [:] }
        var positions: [ArcControl: CGPoint] = [:]
        for (key, value) in stored {
            guard let control = ArcControl(rawValue: key), value.count == 2 else { continue }
            positions[control] = CGPoint(x: value[0], y: value[1])
        }
        return positions
    }

    static func savePositions(_ positions: [ArcControl: CGPoint]) {
        var stored: [String: [Double]] = [:]
        for (control, point) in positions {
            stored[control.rawValue] = [Double(point.x), Double(point.y)]
        }
        UserDefaults.standard.set(stored, forKey: positionsKey)
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
    @State private var readoutSize = CGSize(width: 190, height: 110)
    @State private var isArranging = ArcRemoteView.previewArranging
    @State private var customPositions = ArcControl.loadPositions()   // Normalized, see ArcLayout
    @State private var dragOrigins: [ArcControl: CGPoint] = [:]
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
                    if isArranging {
                        // Tapping empty space finishes arranging, like the Home Screen
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { finishArranging() }
                    }

                    TimerArc(layout: layout, timer: timer, pickingMinutes: $pickingMinutes)
                        .allowsHitTesting(!isArranging)
                        .opacity(isArranging ? 0.4 : 1)

                    if isArranging {
                        ArrangeHeader(alignTrailing: hand == .left,
                                      canReset: !customPositions.isEmpty,
                                      onReset: resetArrangement,
                                      onDone: finishArranging)
                            .padding(.horizontal, layout.margin)
                            .padding(.top, 52)
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: hand == .right ? .topLeading : .topTrailing)
                    } else {
                        let origin = layout.readoutOrigin(for: readoutSize)
                        TimerReadout(timer: timer, pointerActive: pointer.isActive, pickingMinutes: pickingMinutes,
                                     alignTrailing: hand == .left, timeSize: layout.unit * 0.19)
                            .fixedSize()
                            .onGeometryChange(for: CGSize.self) { $0.size } action: { readoutSize = $0 }
                            .position(x: origin.x + readoutSize.width / 2, y: origin.y + readoutSize.height / 2)
                    }

                    controls(layout)
                }
                .coordinateSpace(.named(Self.arcSpace))
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
        .animation(.easeOut(duration: 0.2), value: isArranging)
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
            #if DEBUG
            // `-previewLimit <seconds> -previewElapsed <seconds>` stage a timer state for layout work
            let defaults = UserDefaults.standard
            if defaults.double(forKey: "previewLimit") > 0 {
                timer.config.totalDuration = defaults.double(forKey: "previewLimit")
            }
            if defaults.double(forKey: "previewElapsed") > 0 {
                timer.elapsedTime = defaults.double(forKey: "previewElapsed")
            }
            #endif
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            pointer.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pointer.cancel() }
        }
    }

    // MARK: - Controls

    private static let arcSpace = "arcRemote"

    private func controls(_ layout: ArcLayout) -> some View {
        ForEach(ArcControl.allCases) { control in
            let diameter = control == .next ? layout.primaryDiameter : layout.secondaryDiameter

            controlBody(control, diameter: diameter)
                .allowsHitTesting(!isArranging)
                .modifier(Wobble(active: isArranging, seed: Double(control.defaultDegrees)))
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
                .gesture(isArranging ? moveGesture(control, layout: layout, diameter: diameter) : nil)
                .simultaneousGesture(canStartArranging(from: control) ? arrangeGesture : nil)
                .opacity(pointer.isActive && control != .pointer ? 0.3 : 1)
                .zIndex(dragOrigins[control] == nil ? 0 : 1)
                .position(position(of: control, in: layout))
        }
    }

    @ViewBuilder
    private func controlBody(_ control: ArcControl, diameter: CGFloat) -> some View {
        switch control {
        case .previous:
            ArcButton(systemImage: "chevron.left", label: "Previous", diameter: diameter) {
                connectionManager.previousSlide()
            }
        case .next:
            ArcButton(systemImage: "chevron.right", label: "Next", diameter: diameter, prominent: true) {
                if nextClicks { connectionManager.click() } else { connectionManager.nextSlide() }
            }
        case .pointer:
            PointerButton(pointer: pointer, diameter: diameter)
        case .resetTimer:
            ArcButton(systemImage: "arrow.counterclockwise", label: "Reset timer", diameter: diameter) {
                timer.reset()
            }
        case .toggleTimer:
            ArcButton(
                systemImage: timer.isRunning ? "pause.fill" : "play.fill",
                label: timer.isRunning ? "Pause timer" : "Start timer",
                diameter: diameter,
                tint: timer.isRunning ? .orange : .green
            ) {
                timer.toggle()
            }
        case .settings:
            ArcButton(systemImage: "gearshape", label: "Settings", diameter: diameter) {
                showSettings = true
            }
        }
    }

    private func position(of control: ArcControl, in layout: ArcLayout) -> CGPoint {
        if let custom = customPositions[control] {
            return layout.point(normalized: custom)
        }
        return layout.point(radius: control.isInner ? layout.innerRadius : layout.outerRadius,
                            degrees: control.defaultDegrees)
    }

    // MARK: - Arranging

    /// Debug builds can open straight into arrange mode (`-previewArranging`)
    private static var previewArranging: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-previewArranging")
        #else
        false
        #endif
    }

    /// The pointer button is excluded because holding it is how the pointer
    /// works. Arranging is also locked while the timer runs, so a thumb resting
    /// on a button mid-talk can't put the remote into edit mode.
    private func canStartArranging(from control: ArcControl) -> Bool {
        !isArranging && control != .pointer && !timer.isRunning && !pointer.isActive
    }

    private var arrangeGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.8)
            .onEnded { _ in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                isArranging = true
            }
    }

    private func moveGesture(_ control: ArcControl, layout: ArcLayout, diameter: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.arcSpace))
            .onChanged { value in
                let origin = dragOrigins[control] ?? position(of: control, in: layout)
                dragOrigins[control] = origin

                // Keep the whole button on screen
                let inset = diameter / 2 + 4
                let x = min(max(origin.x + value.translation.width, inset), layout.size.width - inset)
                let y = min(max(origin.y + value.translation.height, inset), layout.size.height - inset)
                customPositions[control] = layout.normalized(CGPoint(x: x, y: y))
            }
            .onEnded { _ in
                dragOrigins[control] = nil
                ArcControl.savePositions(customPositions)
            }
    }

    private func finishArranging() {
        dragOrigins = [:]
        isArranging = false
        ArcControl.savePositions(customPositions)
    }

    private func resetArrangement() {
        withAnimation(.spring(duration: 0.4)) {
            customPositions = [:]
        }
        ArcControl.savePositions(customPositions)
    }
}

// MARK: - Arrange Header
/// Replaces the timer readout while buttons are being rearranged
struct ArrangeHeader: View {
    let alignTrailing: Bool
    let canReset: Bool
    let onReset: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 6) {
            Text("Arrange Buttons")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text("Drag each button to where your thumb wants it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(alignTrailing ? .trailing : .leading)

            HStack(spacing: 10) {
                Button("Done", action: onDone)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(.white, in: Capsule())

                if canReset {
                    Button("Reset", action: onReset)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Wobble
/// Home Screen-style jiggle for buttons that can be moved
struct Wobble: ViewModifier {
    let active: Bool
    let seed: Double   // Offsets each button's phase so they don't move in unison

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: !active)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            content.rotationEffect(.degrees(active ? sin(time * 24 + seed) * 2.4 : 0))
        }
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
/// Time gauge on an arc concentric with the button rows, drawn like a watch's
/// chapter ring: a hairline track, one tick per minute, and a glowing head.
///
/// While the timer is stopped, sliding along the arc sets the limit. The bar
/// stays where it was set and drains as the talk counts down. With no limit
/// it sweeps once a minute instead.
struct TimerArc: View {
    let layout: ArcLayout
    @ObservedObject var timer: PresentationTimer
    /// Minutes being picked mid-drag (0 = no limit), nil when not dragging
    @Binding var pickingMinutes: Int?

    static let maxMinutes = 30

    private let tick = UISelectionFeedbackGenerator()

    // Line weights step up by φ² from the hairline
    private let hairline: CGFloat = 1
    private var barWidth: CGFloat { hairline * pow(ArcLayout.phi, 2) }      // ≈ 2.6
    private var headDiameter: CGFloat { hairline * pow(ArcLayout.phi, 5) }  // ≈ 11

    var body: some View {
        let start = layout.timerStartDegrees
        let end = layout.timerEndDegrees
        let track = layout.arc(radius: layout.timerRadius, from: start, to: end)
        let picking = pickingMinutes != nil
        let grow: CGFloat = picking ? ArcLayout.phi : 1
        let glide: Animation? = picking ? nil : .linear(duration: fraction == 0 ? 0.2 : 1.0)

        ZStack {
            // Chapter ring
            ArcTicks(layout: layout, start: start, end: end, count: Self.maxMinutes, lit: 1)
                .stroke(.white.opacity(isOverTime ? 0 : 0.2), style: StrokeStyle(lineWidth: hairline, lineCap: .round))
            ArcTicks(layout: layout, start: start, end: end, count: Self.maxMinutes, lit: isOverTime ? 1 : fraction)
                .stroke(color, style: StrokeStyle(lineWidth: hairline * 1.5, lineCap: .round))
                .animation(glide, value: fraction)

            track.stroke(.white.opacity(0.13), lineWidth: hairline)

            // Remaining time, fading toward its tail
            track
                .trim(from: 0, to: fraction)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.15), color],
                        startPoint: unitPoint(layout.point(radius: layout.timerRadius, degrees: start)),
                        endPoint: unitPoint(layout.point(radius: layout.timerRadius, degrees: start + (end - start) * fraction))
                    ),
                    style: StrokeStyle(lineWidth: barWidth * grow, lineCap: .round)
                )
                .animation(glide, value: fraction)

            ArcHead(layout: layout, start: start, end: end, fraction: fraction, diameter: headDiameter * grow)
                .fill(.white)
                .shadow(color: color.opacity(0.9), radius: 6 * grow)
                .shadow(color: color.opacity(0.5), radius: 14 * grow)
                .animation(glide, value: fraction)

            if picking {
                minuteLabels(start: start, end: end)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: picking)
        // Generous touch band around the thin stroke
        .contentShape(track.strokedPath(StrokeStyle(lineWidth: 56, lineCap: .round)))
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    let minutes = minutes(at: value.location, start: start, end: end)
                    if minutes != pickingMinutes {
                        tick.selectionChanged()
                        pickingMinutes = minutes
                    }
                }
                .onEnded { value in
                    let minutes = minutes(at: value.location, start: start, end: end)
                    timer.config.totalDuration = minutes == 0 ? nil : TimeInterval(minutes * 60)
                    pickingMinutes = nil
                }
        )
        // Locked while running so a stray thumb can't change the limit mid-talk
        .allowsHitTesting(!timer.isRunning)
    }

    /// Scale shown only while sliding, so the resting arc stays quiet
    private func minuteLabels(start: Double, end: Double) -> some View {
        ForEach([10, 20, 30], id: \.self) { minute in
            let degrees = start + (end - start) * Double(minute) / Double(Self.maxMinutes)
            Text("\(minute)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .position(layout.point(radius: layout.timerRadius + 30, degrees: degrees))
        }
    }

    private func unitPoint(_ point: CGPoint) -> UnitPoint {
        UnitPoint(x: point.x / max(layout.size.width, 1), y: point.y / max(layout.size.height, 1))
    }

    private func minutes(at location: CGPoint, start: Double, end: Double) -> Int {
        let across = layout.hand == .right ? layout.pivot.x - location.x : location.x - layout.pivot.x
        let degrees = atan2(layout.pivot.y - location.y, across) * 180 / .pi
        let fraction = min(max((degrees - start) / (end - start), 0), 1)
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
        if pickingMinutes != nil { return .white }
        guard let progress = timer.progress else { return .white }
        return TimerTint.color(progress: progress)
    }
}

// MARK: - Timer Tint
/// Soft tints rather than system signal colors: readable in a dark room
/// without glaring at the presenter. Shared by the arc and the readout.
enum TimerTint {
    static let onTrack = Color(red: 0.56, green: 0.93, blue: 0.80)   // Mint
    static let wrapUp = Color(red: 1.0, green: 0.82, blue: 0.48)     // Amber
    static let urgent = Color(red: 1.0, green: 0.62, blue: 0.36)     // Orange
    static let over = Color(red: 1.0, green: 0.42, blue: 0.40)       // Coral

    static func color(progress: Double) -> Color {
        if progress >= 1.0 { return over }
        if progress >= 0.9 { return urgent }
        if progress >= 0.75 { return wrapUp }
        return onTrack
    }
}

// MARK: - Arc Ticks
/// Minute marks just outside the track; every fifth is φ times longer.
/// `lit` draws only the marks up to that fraction of the arc.
struct ArcTicks: Shape {
    let layout: ArcLayout
    let start: Double
    let end: Double
    let count: Int
    var lit: Double

    var animatableData: Double {
        get { lit }
        set { lit = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let gap: CGFloat = 6
        let minor: CGFloat = 5
        let major = minor * ArcLayout.phi * ArcLayout.phi

        var path = Path()
        guard lit > 0 else { return path }
        for index in 0...count {
            let position = Double(index) / Double(count)
            guard position <= lit + 0.0001 else { break }
            let degrees = start + (end - start) * position
            let length = index % 5 == 0 ? major : minor
            path.move(to: layout.point(radius: layout.timerRadius + gap, degrees: degrees))
            path.addLine(to: layout.point(radius: layout.timerRadius + gap + length, degrees: degrees))
        }
        return path
    }
}

// MARK: - Arc Head
/// The dot at the leading end of the bar
struct ArcHead: Shape {
    let layout: ArcLayout
    let start: Double
    let end: Double
    var fraction: Double
    var diameter: CGFloat

    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(fraction, diameter) }
        set { fraction = newValue.first; diameter = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let center = layout.point(radius: layout.timerRadius, degrees: start + (end - start) * fraction)
        return Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                      width: diameter, height: diameter))
    }
}

// MARK: - Timer Readout
struct TimerReadout: View {
    @ObservedObject var timer: PresentationTimer
    let pointerActive: Bool
    /// Minutes being picked on the arc (0 = no limit), nil when not dragging
    let pickingMinutes: Int?
    let alignTrailing: Bool
    var timeSize: CGFloat = 72

    var body: some View {
        VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 0) {
            Text(timeText)
                .font(.system(size: timeSize, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timeColor)
                .contentTransition(.numericText())
                .animation(.default, value: timeText)

            Text(caption)
                // Three golden steps below the time
                .font(.system(size: timeSize / pow(ArcLayout.phi, 3), weight: .medium, design: .rounded))
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
            if timer.elapsedTime >= total { return TimerTint.over }
            if timer.elapsedTime >= total * 0.9 { return TimerTint.urgent }
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
