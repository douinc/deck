import Foundation
import AppKit
import Combine

/// Abstracts accessibility permission checks and requests
/// Provides reactive updates when permission status changes
final class PermissionService: ObservableObject {
    static let shared = PermissionService()

    // MARK: - Published Properties
    @Published private(set) var hasAccessibilityPermission: Bool = false

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

        if hasPermission != hasAccessibilityPermission {
            hasAccessibilityPermission = hasPermission
        }

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

    /// Starts polling for permission changes (useful during onboarding)
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
