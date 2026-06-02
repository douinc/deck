import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject var connectionManager: WatchConnectionManager
    @EnvironmentObject var gestureManager: GestureManager
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    @AppStorage("gestureMode") private var gestureMode = "doubleTap"
    @State private var timerStartDate: Date?
    @State private var accumulatedTime: TimeInterval = 0
    @State private var timerRunning = false
    @State private var showSettings = false
    @State private var crownOffset: Double = 0
    @State private var lastCrownDetent: Int = 0
    @AppStorage("invertCrown") private var invertCrown = false

    private var isFlickMode: Bool { gestureMode == "flickWrist" }

    private func elapsedTime(at date: Date) -> TimeInterval {
        if timerRunning, let start = timerStartDate {
            return accumulatedTime + date.timeIntervalSince(start)
        }
        return accumulatedTime
    }

    private func formattedTime(at date: Date) -> String {
        let total = Int(elapsedTime(at: date))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            GeometryReader { geometry in
                if isFlickMode {
                    flickModeLayout(geometry: geometry, date: context.date)
                } else {
                    doubleTapModeLayout(geometry: geometry, date: context.date)
                }
            }
        }
        .focusable()
        .digitalCrownRotation(
            $crownOffset,
            from: -10000.0,
            through: 10000.0,
            sensitivity: .medium,
            isContinuous: true
        )
        .onChange(of: crownOffset) { _, newValue in
            let detent = Int(newValue.rounded())
            guard detent != lastCrownDetent else { return }
            let isForward = invertCrown ? (detent < lastCrownDetent) : (detent > lastCrownDetent)
            WKInterfaceDevice.current().play(.click)
            if isForward {
                connectionManager.nextSlide()
            } else {
                connectionManager.previousSlide()
            }
            lastCrownDetent = detent
        }
    }

    // MARK: - Double Tap Mode Layout

    @ViewBuilder
    private func doubleTapModeLayout(geometry: GeometryProxy, date: Date) -> some View {
        VStack(spacing: 2) {
            Button(action: {
                WKInterfaceDevice.current().play(.directionUp)
                connectionManager.nextSlide()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 32, weight: .bold))
                    .frame(width: geometry.size.width * 0.45, height: geometry.size.width * 0.45)
                    .background(Color.blue.opacity(isLuminanceReduced ? 0.15 : 0.35))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .modifier(PrimaryGestureShortcut())

            Spacer()

            // Bottom row: Previous, Timer, Settings
            HStack(spacing: 8) {
                // Previous slide — small circular button
                Button(action: {
                    WKInterfaceDevice.current().play(.directionDown)
                    connectionManager.previousSlide()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Color.blue.opacity(isLuminanceReduced ? 0.1 : 0.25))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                timerView(date: date)

                Spacer()

                settingsButton
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(gestureManager)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    // MARK: - Flick Mode Layout

    @ViewBuilder
    private func flickModeLayout(geometry: GeometryProxy, date: Date) -> some View {
        VStack(spacing: 6) {
            // Previous slide button
            Button(action: {
                WKInterfaceDevice.current().play(.directionDown)
                connectionManager.previousSlide()
            }) {
                ZStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 32, weight: .bold))

                    if gestureManager.lastGesture == .previous {
                        Image(systemName: gestureManager.isLocked ? "lock.fill" : "hand.wave.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                            .opacity(gestureManager.gestureLockEnabled ? gestureManager.lockProgress : 1.0)
                            .offset(x: 40, y: -10)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: geometry.size.height * 0.30)
                .background(
                    gestureManager.lastGesture == .previous
                        ? Color.yellow.opacity(gestureManager.gestureLockEnabled ? 0.3 * gestureManager.lockProgress : 0.3)
                        : Color.blue.opacity(isLuminanceReduced ? 0.1 : 0.3)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .animation(.easeOut(duration: 0.2), value: gestureManager.lastGesture)
                .animation(.linear(duration: 0.05), value: gestureManager.lockProgress)
            }
            .buttonStyle(.plain)
            .disabled(gestureManager.noGoingBack)
            .opacity(gestureManager.noGoingBack ? 0.3 : 1.0)

            // Timer + gesture toggle + settings row
            HStack(spacing: 4) {
                // Gesture toggle — tap or hardware double-tap to toggle
                Button {
                    gestureManager.toggle()
                    WKInterfaceDevice.current().play(gestureManager.isEnabled ? .stop : .start)
                } label: {
                    ZStack {
                        Image(systemName: gestureManager.isEnabled ? "hand.wave.fill" : "hand.wave")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(gestureManager.isEnabled ? .yellow : .secondary)

                        if gestureManager.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.orange)
                                .offset(x: 8, y: -8)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .background(
                        gestureManager.isLocked
                            ? Color.orange.opacity(0.2 * gestureManager.lockProgress)
                            : gestureManager.isEnabled
                                ? Color.yellow.opacity(0.15)
                                : Color.white.opacity(0.08)
                    )
                    .clipShape(Circle())
                    .animation(.easeOut(duration: 0.2), value: gestureManager.isEnabled)
                    .animation(.linear(duration: 0.05), value: gestureManager.lockProgress)
                }
                .buttonStyle(.plain)
                .modifier(PrimaryGestureShortcut())

                Spacer()

                timerView(date: date)

                Spacer()

                settingsButton
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(gestureManager)
                }
            }

            // Next slide button
            Button(action: {
                WKInterfaceDevice.current().play(.directionUp)
                connectionManager.nextSlide()
            }) {
                ZStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 32, weight: .bold))

                    if gestureManager.lastGesture == .next {
                        Image(systemName: gestureManager.isLocked ? "lock.fill" : "hand.wave.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                            .opacity(gestureManager.gestureLockEnabled ? gestureManager.lockProgress : 1.0)
                            .offset(x: 40, y: -10)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: geometry.size.height * 0.30)
                .background(
                    gestureManager.lastGesture == .next
                        ? Color.yellow.opacity(gestureManager.gestureLockEnabled ? 0.3 * gestureManager.lockProgress : 0.3)
                        : Color.blue.opacity(isLuminanceReduced ? 0.1 : 0.3)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .animation(.easeOut(duration: 0.2), value: gestureManager.lastGesture)
                .animation(.linear(duration: 0.05), value: gestureManager.lockProgress)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func timerView(date: Date) -> some View {
        VStack(spacing: 2) {
            Text(formattedTime(at: date))
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .foregroundColor(timerRunning ? .green : .white)

            HStack(spacing: 4) {
                Circle()
                    .fill(connectionManager.isConnectedToMac ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(connectionManager.isConnectedToMac ? "Connected" : "Disconnected")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .opacity(isLuminanceReduced ? 0.6 : 1.0)
        .onTapGesture {
            toggleTimer()
        }
        .onLongPressGesture {
            resetTimer()
        }
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: isFlickMode ? 30 : 36, height: isFlickMode ? 30 : 36)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer

    private func resetTimer() {
        timerStartDate = nil
        accumulatedTime = 0
        timerRunning = false
        WKInterfaceDevice.current().play(.notification)
    }

    private func toggleTimer() {
        if timerRunning {
            accumulatedTime = elapsedTime(at: Date())
            timerStartDate = nil
            timerRunning = false
            WKInterfaceDevice.current().play(.stop)
        } else {
            timerStartDate = Date()
            timerRunning = true
            WKInterfaceDevice.current().play(.start)
        }
    }
}

/// Applies `.handGestureShortcut(.primaryAction)` on watchOS 11+, which maps
/// the hardware double-tap gesture to this button. On watchOS 10 the button
/// remains tap-only; the modifier is a no-op.
private struct PrimaryGestureShortcut: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 11.0, *) {
            content.handGestureShortcut(.primaryAction)
        } else {
            content
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectionManager())
        .environmentObject(GestureManager())
}
