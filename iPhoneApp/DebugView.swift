import SwiftUI

// MARK: - iOS Debug View
struct ConnectionDebugView: View {
    @ObservedObject var connectionManager: iPhoneConnectionManager
    @State private var showCopiedAlert = false

    var body: some View {
        NavigationView {
            List {
                // Status Section
                Section("Connection Status") {
                    StatusRow(label: "Connected", value: connectionManager.isConnected ? "Yes" : "No",
                              color: connectionManager.isConnected ? .green : .red)
                    StatusRow(label: "Searching", value: connectionManager.isSearching ? "Yes" : "No",
                              color: connectionManager.isSearching ? .blue : .gray)
                    StatusRow(label: "Status", value: connectionManager.statusMessage)
                }

                // Peer Info Section
                Section("Peer Information") {
                    StatusRow(label: "Connected Mac", value: connectionManager.connectedMac?.displayName ?? "None")
                    StatusRow(label: "Available Macs", value: "\(connectionManager.availableMacs.count)")

                    if !connectionManager.availableMacs.isEmpty {
                        ForEach(connectionManager.availableMacs, id: \.displayName) { mac in
                            HStack {
                                Text(mac.displayName)
                                    .font(.caption)
                                Spacer()
                                Button("Connect") {
                                    connectionManager.connectTo(mac)
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                    }
                }

                // Session State Section
                Section("Internal State") {
                    StatusRow(label: "Session", value: connectionManager.sessionState)
                    StatusRow(label: "Browser", value: connectionManager.browserState)
                    if let error = connectionManager.lastError {
                        StatusRow(label: "Last Error", value: error, color: .red)
                    }
                }

                // Actions Section
                Section("Actions") {
                    Button("Restart Browser") {
                        connectionManager.stopBrowsing()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            connectionManager.startBrowsing()
                        }
                    }

                    Button("Disconnect") {
                        connectionManager.disconnect()
                    }
                    .foregroundColor(.red)

                    Button("Copy Debug Info") {
                        UIPasteboard.general.string = connectionManager.debugInfo
                        showCopiedAlert = true
                    }

                    Button("Clear Logs") {
                        connectionManager.clearDebugLogs()
                    }
                }

                // Debug Logs Section
                Section("Debug Logs (\(connectionManager.debugLogs.count))") {
                    if connectionManager.debugLogs.isEmpty {
                        Text("No logs yet")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(connectionManager.debugLogs) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(entry.level.rawValue)
                                    Text(entry.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(entry.message)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Full Debug Info Section
                Section("Full Debug Info") {
                    Text(connectionManager.debugInfo)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Connection Debug")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Copied!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Debug info copied to clipboard")
            }
        }
    }
}

// MARK: - Status Row Helper
struct StatusRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(color)
                .font(.system(.body, design: .monospaced))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    ConnectionDebugView(connectionManager: iPhoneConnectionManager())
}
