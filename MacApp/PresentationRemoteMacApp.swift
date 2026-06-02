import SwiftUI
import Combine

// MARK: - Mac App Entry Point

@main
struct DeckMacApp: App {
    @StateObject private var coordinator = AppCoordinator.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu Bar App
        MenuBarExtra {
            MenuBarView(
                viewModel: coordinator.menuBarViewModel,
                preferences: coordinator.preferences
            )
        } label: {
            MenuBarIcon(isConnected: coordinator.menuBarViewModel.isConnected)
        }

        // Settings Window
        Settings {
            SettingsView(preferences: coordinator.preferences)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var welcomeWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppCoordinator.shared.didFinishLaunching()

        // Observe when welcome should be hidden (coordinator handles the logic)
        AppCoordinator.shared.$showWelcome
            .dropFirst() // Skip initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showWelcome in
                if !showWelcome {
                    self?.closeWelcomeWindow()
                }
            }
            .store(in: &cancellables)

        // Show welcome window if needed
        if AppCoordinator.shared.showWelcome {
            showWelcomeWindow()
        }
    }

    private func showWelcomeWindow() {
        // Create the welcome window
        let welcomeView = WelcomeView(viewModel: AppCoordinator.shared.welcomeViewModel)
        let hostingController = NSHostingController(rootView: welcomeView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Deck"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 520, height: 560))
        window.center()
        window.delegate = self // Handle manual close

        // Keep reference to prevent deallocation
        self.welcomeWindow = window

        // Show the window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func closeWelcomeWindow() {
        welcomeWindow?.close()
        welcomeWindow = nil
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === welcomeWindow else {
            return
        }

        // User manually closed the window - mark onboarding as incomplete but still revert to accessory
        welcomeWindow = nil

        // Revert to accessory mode (no dock icon)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        cancellables.removeAll()
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var preferences: PreferencesManager
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section("About") {
                HStack {
                    Image(systemName: "cursorarrow.click.2")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading) {
                        Text("Deck")
                            .font(.headline)
                        Text("Control presentations from your iPhone")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            Text("Version \(version)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section("General") {
                Toggle("Launch at Login", isOn: $preferences.launchAtLogin)
            }

            Section("Permissions") {
                HStack {
                    Text("Accessibility Permission")
                    Spacer()
                    if PermissionService.shared.hasAccessibilityPermission {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Granted")
                            .foregroundColor(.secondary)
                    } else {
                        Button("Grant Permission") {
                            PermissionService.shared.requestPermission()
                        }
                    }
                }
            }

            Section("Advanced") {
                Toggle("Show Debug Menu", isOn: $preferences.debugMenuEnabled)

                Button("Reset Onboarding") {
                    showResetConfirmation = true
                }
                .foregroundStyle(.red)
            }

            Section("Help") {
                Link(destination: URL(string: "https://github.com/douinc/deck")!) {
                    Label("View on GitHub", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/douinc/deck/issues")!) {
                    Label("Report an Issue", systemImage: "exclamationmark.bubble")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 480)
        .alert("Reset Onboarding?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                preferences.reset()
            }
        } message: {
            Text("This will show the welcome screen again on next launch.")
        }
    }
}
