import SwiftUI

/// Menu bar dropdown interface
/// Pure presentation layer consuming MenuBarViewModel
struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var preferences: PreferencesManager
    @State private var showDebugWindow = false

    var body: some View {
        Group {
            // Status message
            Text(viewModel.statusText)

            // Connected devices
            if !viewModel.connectedDeviceNames.isEmpty {
                ForEach(viewModel.connectedDeviceNames, id: \.self) { deviceName in
                    Label(deviceName, systemImage: "iphone")
                }
            }

            // Last command
            if let lastCommand = viewModel.lastCommandText {
                Text("Last: \(lastCommand)")
            }

            Divider()

            // Start/Stop listening toggle
            if viewModel.isListening {
                Button("Stop Listening") {
                    viewModel.stopListening()
                }
            } else {
                Button("Start Listening") {
                    viewModel.startListening()
                }
            }

            Divider()

            // Accessibility permission status
            if viewModel.hasAccessibilityPermission {
                Label("Accessibility OK", systemImage: "checkmark.circle")
            } else {
                Button("Grant Accessibility") {
                    viewModel.requestPermissions()
                }
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
            Button("Quit") {
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
