import Foundation
import CoreGraphics

/// Pure keystroke injection service
/// Sends keyboard events to the frontmost application
final class KeystrokeService {
    static let shared = KeystrokeService()

    private let permissionService: PermissionService

    // MARK: - Initialization
    init(permissionService: PermissionService = .shared) {
        self.permissionService = permissionService
    }

    // MARK: - Public Methods

    /// Sends a remote command as a keystroke
    /// - Parameter command: The command to send
    /// - Returns: true if keystroke was sent, false if permission denied or no keycode
    @discardableResult
    func sendCommand(_ command: RemoteCommand) -> Bool {
        // Skip keepalive commands - no keystroke needed
        guard let keyCode = command.keyCode else {
            print("No keystroke for command: \(command.rawValue)")
            return true // Not an error, just no keystroke needed
        }

        guard permissionService.hasAccessibilityPermission else {
            print("No accessibility permission - cannot send keystroke")
            return false
        }

        sendKeyPress(keyCode: keyCode)
        print("Sent keystroke for: \(command.rawValue)")
        return true
    }

    // MARK: - Private Methods

    private func sendKeyPress(keyCode: UInt16, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down event
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)

        // Small delay between key down and key up
        usleep(10000) // 10ms

        // Key up event
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Convenience Methods

    func nextSlide() {
        sendCommand(.nextSlide)
    }

    func previousSlide() {
        sendCommand(.previousSlide)
    }

    func startPresentation() {
        sendCommand(.startPresentation)
    }

    func endPresentation() {
        sendCommand(.endPresentation)
    }
}
