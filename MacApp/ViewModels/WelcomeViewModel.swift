import Foundation
import Combine
import AppKit

/// View model for the welcome/onboarding wizard
/// Manages step progression and permission validation
final class WelcomeViewModel: ObservableObject {

    // MARK: - Types

    enum WelcomeStep: Int, CaseIterable {
        case introduction
        case accessibilityPermission
        case connectiPhone
        case complete

        var title: String {
            switch self {
            case .introduction: return "Welcome"
            case .accessibilityPermission: return "Allow Deck"
            case .connectiPhone: return "Connect iPhone"
            case .complete: return "All Set!"
            }
        }
    }

    // MARK: - Published Properties

    @Published private(set) var currentStep: WelcomeStep = .introduction
    @Published private(set) var canProceed: Bool = true
    @Published private(set) var hasPermission: Bool = false
    @Published private(set) var needsRestart: Bool = false
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var localNetworkDenied: Bool = false

    /// The name the iPhone shows for this Mac, so instructions can quote it.
    let macDisplayName: String = Host.current().localizedName ?? "your Mac"

    // MARK: - Services

    let permissionService: PermissionService
    let preferences: PreferencesManager
    let connectionManager: MacConnectionManager?

    // MARK: - Callbacks

    var onComplete: (() -> Void)?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        permissionService: PermissionService = .shared,
        preferences: PreferencesManager = .shared,
        connectionManager: MacConnectionManager? = nil
    ) {
        self.permissionService = permissionService
        self.preferences = preferences
        self.connectionManager = connectionManager

        setupBindings()
    }

    // MARK: - Private Setup

    private func setupBindings() {
        // Observe permission changes
        permissionService.$hasAccessibilityPermission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasPermission in
                guard let self = self else { return }

                // Detect permission granted for the first time - requires restart
                if hasPermission && !self.hasPermission && !self.needsRestart {
                    self.needsRestart = true
                }

                self.hasPermission = hasPermission
                self.updateCanProceed()
            }
            .store(in: &cancellables)

        // Live iPhone connection status for the "Connect your iPhone" step
        connectionManager?.$connectedDevices
            .receive(on: DispatchQueue.main)
            .map { $0.first?.displayName }
            .assign(to: &$connectedDeviceName)

        connectionManager?.$localNetworkDenied
            .receive(on: DispatchQueue.main)
            .assign(to: &$localNetworkDenied)
    }

    private func updateCanProceed() {
        switch currentStep {
        case .introduction:
            canProceed = true
        case .accessibilityPermission:
            canProceed = hasPermission
        case .connectiPhone:
            // Never block on the phone: people may set it up later.
            canProceed = true
        case .complete:
            canProceed = true
        }
    }

    // MARK: - Public Methods

    func nextStep() {
        let allSteps = WelcomeStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex < allSteps.count - 1 else {
            return
        }

        currentStep = allSteps[currentIndex + 1]
        updateCanProceed()

        // Start permission polling when entering permission step
        if currentStep == .accessibilityPermission && !hasPermission {
            permissionService.startPolling()
        }
    }

    func previousStep() {
        let allSteps = WelcomeStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex > 0 else {
            return
        }

        currentStep = allSteps[currentIndex - 1]
        updateCanProceed()
    }

    /// Restarts the guide from the first step (used by "Setup Guide…").
    func restart() {
        currentStep = hasPermission ? .connectiPhone : .introduction
        updateCanProceed()
    }

    func openLocalNetworkSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")!
        NSWorkspace.shared.open(url)
    }

    func requestPermission() {
        permissionService.requestPermission()
    }

    func openSystemPreferences() {
        permissionService.openSystemPreferences()
    }

    func completeOnboarding() {
        preferences.markOnboardingComplete()
        onComplete?()
    }

    func startPermissionPolling() {
        guard !hasPermission else { return }
        permissionService.startPolling()
    }

    func stopPermissionPolling() {
        // Intentionally a no-op: the coordinator keeps polling until the
        // permission is granted (also when the guide is closed early), so the
        // automatic relaunch still happens if it's granted later.
    }

    func restartApp() {
        AppRelauncher.relaunch()
    }
}
