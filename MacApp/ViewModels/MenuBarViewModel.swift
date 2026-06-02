import Foundation
import Combine
import MultipeerConnectivity

/// View model for the menu bar interface
/// Transforms connection manager and service states into UI-ready properties
final class MenuBarViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var statusText: String = "Not running"
    @Published private(set) var connectedDeviceNames: [String] = []
    @Published private(set) var lastCommandText: String?
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var isListening: Bool = false
    @Published private(set) var hasAccessibilityPermission: Bool = false
    @Published private(set) var availableUpdate: String?

    // MARK: - Services

    let connectionManager: MacConnectionManager
    let preferences: PreferencesManager
    let permissionService: PermissionService
    let keystrokeService: KeystrokeService
    let updateChecker: UpdateChecker

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        connectionManager: MacConnectionManager,
        preferences: PreferencesManager = .shared,
        permissionService: PermissionService = .shared,
        keystrokeService: KeystrokeService = .shared,
        updateChecker: UpdateChecker
    ) {
        self.connectionManager = connectionManager
        self.preferences = preferences
        self.permissionService = permissionService
        self.keystrokeService = keystrokeService
        self.updateChecker = updateChecker

        setupBindings()
        setupCommandHandler()
    }

    // MARK: - Private Setup

    private func setupBindings() {
        // Connection status
        connectionManager.$statusMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$statusText)

        // Connected devices
        connectionManager.$connectedDevices
            .receive(on: DispatchQueue.main)
            .map { devices in
                devices.map { $0.displayName }
            }
            .assign(to: &$connectedDeviceNames)

        // Connection state
        connectionManager.$connectedDevices
            .receive(on: DispatchQueue.main)
            .map { !$0.isEmpty }
            .assign(to: &$isConnected)

        // Listening state
        connectionManager.$isAdvertising
            .receive(on: DispatchQueue.main)
            .assign(to: &$isListening)

        // Last command
        connectionManager.$lastCommand
            .receive(on: DispatchQueue.main)
            .map { command in
                command?.rawValue
            }
            .assign(to: &$lastCommandText)

        // Permission state
        permissionService.$hasAccessibilityPermission
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasAccessibilityPermission)

        // Available update
        updateChecker.$availableUpdate
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableUpdate)
    }

    private func setupCommandHandler() {
        connectionManager.onCommandReceived = { [weak self] command in
            self?.keystrokeService.sendCommand(command)
        }
    }

    // MARK: - Public Methods

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        if !hasAccessibilityPermission {
            permissionService.requestPermission()
        }
        connectionManager.startAdvertising()
    }

    func stopListening() {
        connectionManager.stopAdvertising(userInitiated: true)
    }

    func requestPermissions() {
        permissionService.requestPermission()
    }

    // MARK: - Debug Methods

    func testPrevious() {
        keystrokeService.previousSlide()
    }

    func testNext() {
        keystrokeService.nextSlide()
    }

    func restartApp() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
