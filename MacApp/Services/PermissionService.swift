import Foundation
import AppKit
import Combine

/// Abstracts accessibility permission checks and requests
/// Provides reactive updates when permission status changes
final class PermissionService: ObservableObject {
    static let shared = PermissionService()

    // MARK: - Published Properties
    @Published private(set) var hasAccessibilityPermission: Bool = false

    /// Fires when permission flips from denied to granted while Deck is running.
    /// Deck must relaunch for the grant to take effect (see AppRelauncher).
    let permissionGranted = PassthroughSubject<Void, Never>()
    private var hasCompletedInitialCheck = false

    // MARK: - Private Properties
    private var pollingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        checkPermissionStatus()
    }

    deinit {
        stopPolling()
    }

    // MARK: - Public Methods

    /// Checks current accessibility permission status
    @discardableResult
    func checkPermissionStatus() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let hasPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)

        let wasGranted = hasAccessibilityPermission
        if hasPermission != wasGranted {
            hasAccessibilityPermission = hasPermission
        }
        // Permission already on at launch is not a "grant" — only a change
        // observed while running is, which is what avoids a relaunch loop.
        if hasCompletedInitialCheck && hasPermission && !wasGranted {
            stopPolling()
            permissionGranted.send()
        }
        hasCompletedInitialCheck = true

        return hasPermission
    }

    /// Requests accessibility permission (shows system prompt)
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Opens System Settings to Accessibility panel
    func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Polls for permission changes until permission is granted.
    func startPolling(interval: TimeInterval = 1.0) {
        stopPolling()

        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkPermissionStatus()
        }
    }

    /// Stops polling for permission changes
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}
