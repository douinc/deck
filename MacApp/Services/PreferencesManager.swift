import Foundation
import ServiceManagement

/// Manages app preferences and first-launch state using UserDefaults
/// Provides a centralized, testable interface for all app settings
final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let debugMenuEnabled = "debugMenuEnabled"
    }

    // MARK: - Published Properties
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }

    @Published var debugMenuEnabled: Bool {
        didSet {
            defaults.set(debugMenuEnabled, forKey: Keys.debugMenuEnabled)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = oldValue
            }
        }
    }

    // MARK: - Private Properties
    private let defaults: UserDefaults

    // MARK: - Initialization
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load persisted values
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.debugMenuEnabled = defaults.bool(forKey: Keys.debugMenuEnabled)
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Public Methods

    /// Marks onboarding as complete
    func markOnboardingComplete() {
        hasCompletedOnboarding = true
    }

    /// Resets all preferences to defaults (useful for testing)
    func reset() {
        defaults.removeObject(forKey: Keys.hasCompletedOnboarding)
        defaults.removeObject(forKey: Keys.debugMenuEnabled)

        hasCompletedOnboarding = false
        debugMenuEnabled = false
    }
}
