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
        case complete

        var title: String {
            switch self {
            case .introduction: return "Welcome"
            case .accessibilityPermission: return "Permission Required"
            case .complete: return "All Set!"
            }
        }
    }

    // MARK: - Published Properties

    @Published private(set) var currentStep: WelcomeStep = .introduction
    @Published private(set) var canProceed: Bool = true
    @Published private(set) var hasPermission: Bool = false
    @Published private(set) var needsRestart: Bool = false

    // MARK: - Services

    let permissionService: PermissionService
    let preferences: PreferencesManager

    // MARK: - Callbacks

    var onComplete: (() -> Void)?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        permissionService: PermissionService = .shared,
        preferences: PreferencesManager = .shared
    ) {
        self.permissionService = permissionService
        self.preferences = preferences

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
    }

    private func updateCanProceed() {
        switch currentStep {
        case .introduction:
            canProceed = true
        case .accessibilityPermission:
            canProceed = hasPermission
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
        if currentStep == .accessibilityPermission {
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

    func requestPermission() {
        permissionService.requestPermission()
    }

    func openSystemPreferences() {
        permissionService.openSystemPreferences()
    }

    func completeOnboarding() {
        permissionService.stopPolling()
        preferences.markOnboardingComplete()
        onComplete?()
    }

    func startPermissionPolling() {
        permissionService.startPolling()
    }

    func stopPermissionPolling() {
        permissionService.stopPolling()
    }

    func restartApp() {
        // Get the path to the current app
        let bundlePath = Bundle.main.bundlePath

        // Use a shell script to relaunch after a short delay
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 0.5; open \"\(bundlePath)\""]
        task.launch()

        // Terminate the current instance
        NSApplication.shared.terminate(nil)
    }
}
