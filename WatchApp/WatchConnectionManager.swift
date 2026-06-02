import Foundation
import WatchConnectivity
import Combine

class WatchConnectionManager: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published var isReachable = false
    @Published var isConnectedToMac = false

    // MARK: - Private Properties
    private var session: WCSession?
    private var pendingCommand: String?
    private var retryTimer: Timer?
    private let maxRetries = 3
    private var retryCount = 0

    // MARK: - Initialization
    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Send Commands
    func sendCommand(_ command: String) {
        guard let session = session, session.activationState == .activated else {
            print("⌚ WCSession not activated")
            return
        }

        let message = ["command": command]

        if session.isReachable {
            // iPhone is reachable - send immediately
            session.sendMessage(message, replyHandler: { reply in
                DispatchQueue.main.async {
                    if let connected = reply["connectedToMac"] as? Bool {
                        self.isConnectedToMac = connected
                    }
                    print("⌚ Command sent successfully: \(command)")
                }
                self.clearPendingCommand()
            }, errorHandler: { error in
                print("⌚ sendMessage failed: \(error.localizedDescription)")
                self.queueRetry(command: command)
            })
        } else {
            // iPhone not reachable - queue for retry
            print("⌚ iPhone not reachable, queuing command")
            queueRetry(command: command)
        }
    }

    // MARK: - Retry Logic
    private func queueRetry(command: String) {
        pendingCommand = command
        retryCount = 0
        scheduleRetry()
    }

    private func scheduleRetry() {
        retryTimer?.invalidate()

        guard retryCount < maxRetries else {
            print("⌚ Max retries reached, giving up")
            clearPendingCommand()
            return
        }

        retryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.attemptRetry()
        }
    }

    private func attemptRetry() {
        guard let command = pendingCommand,
              let session = session,
              session.isReachable else {
            retryCount += 1
            scheduleRetry()
            return
        }

        let message = ["command": command]
        session.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                if let connected = reply["connectedToMac"] as? Bool {
                    self.isConnectedToMac = connected
                }
            }
            self.clearPendingCommand()
            print("⌚ Retry successful: \(command)")
        }, errorHandler: { [weak self] error in
            print("⌚ Retry failed: \(error.localizedDescription)")
            self?.retryCount += 1
            self?.scheduleRetry()
        })
    }

    private func clearPendingCommand() {
        pendingCommand = nil
        retryTimer?.invalidate()
        retryTimer = nil
        retryCount = 0
    }

    // MARK: - Convenience Methods
    func nextSlide() {
        sendCommand("next")
    }

    func previousSlide() {
        sendCommand("previous")
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectionManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }

        if let error = error {
            print("⌚ WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("⌚ WCSession activated: \(activationState.rawValue)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("⌚ Reachability changed: \(session.isReachable)")
        }

        // Retry pending command if we just became reachable
        if session.isReachable, pendingCommand != nil {
            attemptRetry()
        }
    }

    // Receive status updates from iPhone
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            if let connected = applicationContext["connectedToMac"] as? Bool {
                self.isConnectedToMac = connected
            }
        }
    }
}
