import SwiftUI

/// Menu bar dropdown interface
/// Pure presentation layer consuming MenuBarViewModel
struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var preferences: PreferencesManager
    @State private var showDebugWindow = false

    var body: some View {
        Group {
            // 1. Problems first, each with a one-click fix
            if viewModel.localNetworkDenied {
                Text("⚠️ Your iPhone can't find this Mac")
                Button("Fix: Allow Deck on the Local Network…") {
                    viewModel.openLocalNetworkSettings()
                }
                Divider()
            }

            if !viewModel.hasAccessibilityPermission {
                Text("⚠️ Deck can't change slides yet")
                Button("Fix: Allow Deck in System Settings…") {
                    viewModel.requestPermissions()
                }
                Divider()
            }

            // 2. Where things stand, in plain words
            if viewModel.isConnected {
                ForEach(viewModel.connectedDeviceNames, id: \.self) { deviceName in
                    Text("✅ Connected to \(deviceName)")
                }
                if let lastCommand = viewModel.lastCommandText {
                    Text("Last: \(lastCommand)")
                } else {
                    Text("Tap Next on your iPhone to change slides")
                }
            } else if viewModel.isListening {
                Text("📱 Waiting for your iPhone…")
                Text("Open Deck on your iPhone and tap “\(viewModel.macDisplayName)”")
            } else {
                Text("⏸ Deck is paused")
                Text("Your iPhone can't connect while paused")
            }

            Divider()

            if viewModel.isListening {
                Button("Pause Deck") {
                    viewModel.stopListening()
                }
            } else {
                Button("Resume Deck") {
                    viewModel.startListening()
                }
            }

            Button("Setup Guide…") {
                AppCoordinator.shared.showSetupGuide()
            }

            Divider()

            // Update available
            if let update = viewModel.availableUpdate {
                Button("Update Available (v\(update))") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/douinc/deck/releases/latest")!)
                }

                Divider()
            }

            // Debug menu (conditional)
            if preferences.debugMenuEnabled {
                Menu("Debug") {
                    Button("Test Previous") {
                        viewModel.testPrevious()
                    }
                    .keyboardShortcut("[")

                    Button("Test Next") {
                        viewModel.testNext()
                    }
                    .keyboardShortcut("]")

                    Divider()

                    Button("Show Debug Info") {
                        showDebugWindow = true
                    }
                    .keyboardShortcut("d")

                    Button("Copy Debug Info") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.connectionManager.debugInfo, forType: .string)
                    }

                    Divider()

                    Button("Restart App") {
                        viewModel.restartApp()
                    }
                    .keyboardShortcut("r")
                }
                .popover(isPresented: $showDebugWindow) {
                    MacDebugView(connectionManager: viewModel.connectionManager)
                }

                Divider()
            }

            // Settings
            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",")

            // Quit
            Button("Quit Deck") {
                viewModel.quit()
            }
            .keyboardShortcut("q")
        }
    }
}

// MARK: - Menu Bar Icon

struct MenuBarIcon: View {
    let isConnected: Bool

    var body: some View {
        // Deck logo rendered as a template image so macOS tints it to match
        // the menu bar (black in light mode, white in dark). Dimmed when
        // disconnected to preserve the connection-state cue.
        Image("MenuBarIcon")
            .renderingMode(.template)
            .opacity(isConnected ? 1.0 : 0.45)
    }
}
