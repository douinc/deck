import Foundation
import SwiftUI
import Combine

/// Centralized application lifecycle coordinator
/// Manages services, view models, and orchestrates app behavior
final class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()

    // MARK: - Published State

    @Published var showWelcome: Bool = false

    // MARK: - Services

    let preferences: PreferencesManager
    let permissionService: PermissionService
    let keystrokeService: KeystrokeService
    let connectionManager: MacConnectionManager
    let updateChecker = UpdateChecker()

    // MARK: - View Models

    lazy var menuBarViewModel: MenuBarViewModel = {
        MenuBarViewModel(
            connectionManager: connectionManager,
            preferences: preferences,
            permissionService: permissionService,
            keystrokeService: keystrokeService,
            updateChecker: updateChecker
        )
    }()

    lazy var welcomeViewModel: WelcomeViewModel = {
        let viewModel = WelcomeViewModel(
            permissionService: permissionService,
            preferences: preferences
        )
        viewModel.onComplete = { [weak self] in
            self?.handleOnboardingComplete()
        }
        return viewModel
    }()

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        preferences: PreferencesManager = .shared,
        permissionService: PermissionService = .shared,
        keystrokeService: KeystrokeService = .shared,
        connectionManager: MacConnectionManager? = nil
    ) {
        self.preferences = preferences
        self.permissionService = permissionService
        self.keystrokeService = keystrokeService
        self.connectionManager = connectionManager ?? MacConnectionManager()
    }

    // MARK: - Lifecycle Methods

    /// Called when the app finishes launching
    func didFinishLaunching() {
        // Check permission status
        permissionService.checkPermissionStatus()

        updateChecker.checkIfNeeded()

        if !preferences.hasCompletedOnboarding {
            // First launch - show welcome window
            showWelcome = true
        } else if permissionService.hasAccessibilityPermission {
            // Returning user with permission - auto-start listening
            startListeningIfReady()
        }
    }

    /// Called when onboarding is completed
    func handleOnboardingComplete() {
        showWelcome = false

        // Auto-start listening after onboarding
        if permissionService.hasAccessibilityPermission {
            startListeningIfReady()
        }

        // Bring menu bar to focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Private Methods

    private func startListeningIfReady() {
        guard permissionService.hasAccessibilityPermission else {
            print("Cannot auto-start: missing accessibility permission")
            return
        }

        connectionManager.startAdvertising()
        print("Auto-started listening for connections")
    }
}
