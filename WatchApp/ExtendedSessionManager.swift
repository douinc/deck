import WatchKit

class ExtendedSessionManager: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession?

    func start() {
        guard session?.state != .running else { return }
        session?.invalidate()
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        newSession.start()
        session = newSession
    }

    func stop() {
        session?.invalidate()
        session = nil
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        session = nil
        if reason == .expired {
            start()
        }
    }
}
