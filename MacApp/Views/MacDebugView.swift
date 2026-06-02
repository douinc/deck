import SwiftUI

// MARK: - Mac Debug View
struct MacDebugView: View {
    @ObservedObject var connectionManager: MacConnectionManager
    @State private var showCopiedAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Connection Debug")
                        .font(.headline)
                    Spacer()
                    Button("Copy Info") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(connectionManager.debugInfo, forType: .string)
                        showCopiedAlert = true
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                // Status Section
                GroupBox("Connection Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        DebugRow(label: "Advertising", value: connectionManager.isAdvertising ? "Yes" : "No",
                                 color: connectionManager.isAdvertising ? .green : .red)
                        DebugRow(label: "Status", value: connectionManager.statusMessage)
                        DebugRow(label: "Connected Devices", value: "\(connectionManager.connectedDevices.count)")

                        if !connectionManager.connectedDevices.isEmpty {
                            ForEach(connectionManager.connectedDevices, id: \.displayName) { device in
                                Text("  • \(device.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Internal State Section
                GroupBox("Internal State") {
                    VStack(alignment: .leading, spacing: 8) {
                        DebugRow(label: "Session", value: connectionManager.sessionState)
                        DebugRow(label: "Advertiser", value: connectionManager.advertiserState)
                        if let error = connectionManager.lastError {
                            DebugRow(label: "Last Error", value: error, color: .red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Actions Section
                GroupBox("Actions") {
                    HStack(spacing: 12) {
                        Button("Restart Session") {
                            connectionManager.stopAdvertising(userInitiated: false)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                connectionManager.startAdvertising()
                            }
                        }

                        Button("Clear Logs") {
                            connectionManager.clearDebugLogs()
                        }
                    }
                }

                // Debug Logs Section
                GroupBox("Debug Logs (\(connectionManager.debugLogs.count))") {
                    if connectionManager.debugLogs.isEmpty {
                        Text("No logs yet")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(connectionManager.debugLogs.prefix(50)) { entry in
                                HStack(alignment: .top, spacing: 4) {
                                    Text(entry.level.rawValue)
                                        .font(.caption)
                                    Text(entry.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(width: 60, alignment: .leading)
                                    Text(entry.message)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)

                // Full Debug Info
                GroupBox("Full Debug Info") {
                    Text(connectionManager.debugInfo)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .alert("Copied!", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        }
    }
}

// MARK: - Debug Row Helper
struct DebugRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
                .font(.caption)
            Text(value)
                .foregroundColor(color)
                .font(.system(.caption, design: .monospaced))
        }
    }
}
