import Foundation
import MultipeerConnectivity
import Combine

// MARK: - Mac Connection Manager
class MacConnectionManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAdvertising = false
    @Published var connectedDevices: [MCPeerID] = []
    @Published var lastCommand: RemoteCommand?
    @Published var statusMessage = "Not running"

    // MARK: - Debug Properties
    @Published var debugLogs: [DebugLogEntry] = []
    @Published var sessionState: String = "None"
    @Published var advertiserState: String = "None"
    @Published var lastError: String?

    struct DebugLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let level: LogLevel

        enum LogLevel: String {
            case info = "ℹ️"
            case success = "✅"
            case warning = "⚠️"
            case error = "❌"
            case network = "📡"
        }
    }
    
    // MARK: - Multipeer Properties
    private let myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    
    // MARK: - Callback for keystroke
    var onCommandReceived: ((RemoteCommand) -> Void)?
    
    // MARK: - Debug Logging
    private func debugLog(_ message: String, level: DebugLogEntry.LogLevel = .info) {
        let entry = DebugLogEntry(timestamp: Date(), message: message, level: level)
        DispatchQueue.main.async {
            self.debugLogs.insert(entry, at: 0)
            if self.debugLogs.count > 100 {
                self.debugLogs = Array(self.debugLogs.prefix(100))
            }
        }
        print("[\(level.rawValue)] \(message)")
    }

    func clearDebugLogs() {
        debugLogs.removeAll()
    }

    var debugInfo: String {
        """
        === Mac Connection Debug ===
        My Peer ID: \(myPeerID.displayName)
        Service Type: \(RemoteServiceConfig.serviceType)

        Session State: \(sessionState)
        Advertiser State: \(advertiserState)
        Is Advertising: \(isAdvertising)

        Connected Devices: \(connectedDevices.map { $0.displayName }.joined(separator: ", "))
        Session Peers: \(session?.connectedPeers.map { $0.displayName }.joined(separator: ", ") ?? "None")

        Last Error: \(lastError ?? "None")
        """
    }

    // MARK: - Initialization
    override init() {
        self.myPeerID = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
        super.init()
        debugLog("Initializing with peer ID: \(myPeerID.displayName)", level: .info)
        setupSession()
    }
    
    private func setupSession() {
        debugLog("Setting up session with encryption: optional", level: .network)
        session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .optional  // Changed from .required - more reliable on real networks
        )
        session?.delegate = self
        sessionState = "Created (encryption: optional)"
        debugLog("Session created successfully", level: .success)
    }

    // MARK: - Public Methods
    func startAdvertising() {
        debugLog("Starting advertiser for service: \(RemoteServiceConfig.serviceType)", level: .network)
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: RemoteServiceConfig.serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        isAdvertising = true
        advertiserState = "Advertising: \(RemoteServiceConfig.serviceType)"
        statusMessage = "Waiting for iPhone to connect..."
        debugLog("Advertiser started successfully", level: .success)
    }

    func stopAdvertising(userInitiated: Bool = false) {
        debugLog("Stopping advertiser (userInitiated: \(userInitiated))", level: .network)
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        isAdvertising = false
        advertiserState = "Stopped"
        statusMessage = "Stopped"
    }
    
    func disconnect() {
        session?.disconnect()
        connectedDevices.removeAll()
        statusMessage = "Disconnected"
    }
}

// MARK: - MCSessionDelegate
extension MacConnectionManager: MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.debugLog("SESSION STATE: Connected to \(peerID.displayName)", level: .success)
                self.sessionState = "Connected to \(peerID.displayName)"
                if !self.connectedDevices.contains(peerID) {
                    self.connectedDevices.append(peerID)
                }
                self.statusMessage = "Connected to \(peerID.displayName)"
                self.lastError = nil

            case .connecting:
                self.debugLog("SESSION STATE: Connecting to \(peerID.displayName)", level: .network)
                self.sessionState = "Connecting to \(peerID.displayName)..."
                self.statusMessage = "Connecting to \(peerID.displayName)..."

            case .notConnected:
                self.debugLog("SESSION STATE: Not connected (was: \(peerID.displayName))", level: .warning)
                self.sessionState = "Not connected"
                self.connectedDevices.removeAll { $0 == peerID }
                if self.connectedDevices.isEmpty {
                    self.statusMessage = "Waiting for iPhone to reconnect..."
                    if self.advertiser == nil {
                        self.debugLog("Re-starting advertiser for reconnection", level: .network)
                        self.startAdvertising()
                    }
                } else {
                    self.statusMessage = "Connected to \(self.connectedDevices.count) device(s)"
                }

            @unknown default:
                self.debugLog("SESSION STATE: Unknown state for \(peerID.displayName)", level: .warning)
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Decode the command
        guard let commandString = String(data: data, encoding: .utf8),
              let command = RemoteCommand(rawValue: commandString) else {
            print("⚠️ Failed to decode command")
            return
        }
        
        print("📥 Received command: \(command.rawValue) from \(peerID.displayName)")
        
        DispatchQueue.main.async {
            self.lastCommand = command
            self.onCommandReceived?(command)
        }
    }
    
    // Required delegate methods (not used but must be implemented)
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MacConnectionManager: MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        debugLog("ADVERTISER: Received invitation from '\(peerID.displayName)'", level: .network)
        debugLog("Accepting invitation with session: \(session != nil ? "valid" : "NIL!")", level: .info)
        invitationHandler(true, session)
        debugLog("Invitation accepted, waiting for connection...", level: .success)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        debugLog("ADVERTISER ERROR: \(error.localizedDescription)", level: .error)
        DispatchQueue.main.async {
            self.isAdvertising = false
            self.advertiserState = "Error: \(error.localizedDescription)"
            self.lastError = error.localizedDescription
            self.statusMessage = "Error: \(error.localizedDescription)"
        }
    }
}
