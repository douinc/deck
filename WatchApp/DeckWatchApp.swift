import SwiftUI

@main
struct DeckWatchApp: App {
    @StateObject private var connectionManager = WatchConnectionManager()
    @StateObject private var sessionManager = ExtendedSessionManager()
    @StateObject private var gestureManager = GestureManager()
    @AppStorage("gestureMode") private var gestureMode = "doubleTap"
    @Environment(\.scenePhase) var scenePhase

    private var isFlickMode: Bool { gestureMode == "flickWrist" }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionManager)
                .environmentObject(sessionManager)
                .environmentObject(gestureManager)
                .onAppear {
                    sessionManager.start()
                    wireGestureCallbacks()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        sessionManager.start()
                        if isFlickMode && gestureManager.autoToggleWithWrist {
                            gestureManager.start()
                        }
                    case .inactive:
                        if isFlickMode && gestureManager.autoToggleWithWrist {
                            gestureManager.stop()
                        }
                    case .background:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }

    private func wireGestureCallbacks() {
        gestureManager.onNextSlide = { [weak connectionManager] in
            connectionManager?.nextSlide()
        }
        gestureManager.onPreviousSlide = { [weak connectionManager] in
            connectionManager?.previousSlide()
        }
    }
}
