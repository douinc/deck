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
            preferences: preferences,
            connectionManager: connectionManager
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

        // Always become discoverable right away. Discovery must NOT be gated on
        // Accessibility or on finishing onboarding: previously a first-time user
        // who closed the welcome window, hadn't granted Accessibility yet, or
        // relaunched via "Restart Deck" (which happens before onboarding is
        // marked complete) ended up with a Mac that never advertised, so the
        // iPhone could never find it. Accessibility only affects whether
        // received commands can be turned into keystrokes, and the menu bar
        // already prompts for it.
        startListening()

        // Watch for Accessibility being turned on — from the setup guide, the
        // menu bar "Fix" item, or System Settings directly — and relaunch Deck
        // automatically, because macOS only applies the grant to a new process.
        permissionService.permissionGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.relaunchAfterPermissionGranted() }
            .store(in: &cancellables)
        if !permissionService.hasAccessibilityPermission {
            permissionService.startPolling()
        }

        if !preferences.hasCompletedOnboarding {
            // First launch - show welcome window. If we're back from the
            // automatic relaunch, skip ahead past the permission step.
            if permissionService.hasAccessibilityPermission {
                welcomeViewModel.restart()
            }
            showWelcome = true
        }
    }

    /// Gives the setup guide a moment to show "Allowed — reopening Deck…",
    /// then relaunches.
    private func relaunchAfterPermissionGranted() {
        print("Accessibility granted — relaunching Deck so it takes effect")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            AppRelauncher.relaunch()
        }
    }

    /// Reopens the setup guide from the menu bar.
    func showSetupGuide() {
        welcomeViewModel.restart()
        showWelcome = true
    }

    /// Called when onboarding is completed
    func handleOnboardingComplete() {
        showWelcome = false

        // Make sure we're discoverable (no-op if already advertising)
        if !connectionManager.isAdvertising {
            startListening()
        }

        // Bring menu bar to focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Private Methods

    private func startListening() {
        if !permissionService.hasAccessibilityPermission {
            print("Listening without Accessibility permission: commands won't send keystrokes until it's granted")
        }
        connectionManager.startAdvertising()
        print("Auto-started listening for connections")
    }
}
