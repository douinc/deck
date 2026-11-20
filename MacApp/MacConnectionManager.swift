import Foundation
import AppKit
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

    // MARK: - Local Network Privacy (macOS 15+)
    /// True when macOS has denied Deck Local Network access. In that state the
    /// iPhone can never discover this Mac, so the menu bar surfaces a fix.
    @Published private(set) var localNetworkDenied = false
    private let localNetworkMonitor = LocalNetworkPermissionMonitor()
    private var cancellables = Set<AnyCancellable>()

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

    /// Set when the user explicitly chooses "Stop Listening". While set we never
    /// restart advertising on our own (reconnects, wake from sleep, retries).
    private var userStoppedAdvertising = false
    private var advertiseRetryWorkItem: DispatchWorkItem?

    // MARK: - Connection Health Watchdog
    // MultipeerConnectivity can keep reporting `.connected` long after the
    // underlying path is dead ("half-open"). We track the time of the last
    // inbound packet (any command, including keepalives) and tear the session
    // down if it goes stale, forcing a clean reconnect.
    private var watchdogTimer: Timer?
    private var lastReceivedTime = Date()
    private let staleTimeout: TimeInterval = 15.0  // ~5 missed 3s keepalives

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
        self.myPeerID = RemoteServiceConfig.persistentPeerID(displayName: Host.current().localizedName ?? "Mac")
        super.init()
        debugLog("Initializing with peer ID: \(myPeerID.displayName)", level: .info)
        setupSession()
        setupLocalNetworkMonitor()
        observeSystemWake()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func setupLocalNetworkMonitor() {
        localNetworkMonitor.$isDenied
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] denied in
                guard let self = self else { return }
                self.localNetworkDenied = denied
                if denied {
                    self.debugLog("Local Network access is denied — iPhone cannot discover this Mac", level: .error)
                    self.lastError = "Local Network access denied"
                }
            }
            .store(in: &cancellables)
    }

    /// Bonjour advertisements frequently go stale across sleep/wake and network
    /// changes, leaving the Mac invisible until the app is relaunched. Restart
    /// the advertiser whenever the Mac wakes up.
    private func observeSystemWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func systemDidWake() {
        DispatchQueue.main.async {
            guard self.isAdvertising, !self.userStoppedAdvertising else { return }
            self.debugLog("System woke from sleep, restarting advertiser", level: .network)
            self.startAdvertising()
        }
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
    /// Starts advertising so iPhones can discover this Mac. Safe to call
    /// repeatedly: any existing advertiser is torn down first, so we never end
    /// up with two advertisers for the same peer.
    func startAdvertising() {
        debugLog("Starting advertiser for service: \(RemoteServiceConfig.serviceType)", level: .network)
        userStoppedAdvertising = false
        advertiseRetryWorkItem?.cancel()
        advertiseRetryWorkItem = nil
        advertiser?.delegate = nil
        advertiser?.stopAdvertisingPeer()
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: RemoteServiceConfig.serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        isAdvertising = true
        advertiserState = "Advertising: \(RemoteServiceConfig.serviceType)"
        if connectedDevices.isEmpty {
            statusMessage = "Waiting for iPhone to connect..."
        }
        debugLog("Advertiser started successfully", level: .success)

        // Re-probe Local Network access (this also triggers the macOS 15+
        // permission prompt on first launch, while the user is at the Mac).
        localNetworkMonitor.start()
    }

    func stopAdvertising(userInitiated: Bool = false) {
        debugLog("Stopping advertiser (userInitiated: \(userInitiated))", level: .network)
        if userInitiated {
            userStoppedAdvertising = true
        }
        advertiseRetryWorkItem?.cancel()
        advertiseRetryWorkItem = nil
        advertiser?.delegate = nil
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        isAdvertising = false
        advertiserState = "Stopped"
        statusMessage = "Stopped"
    }
    
    func disconnect() {
        stopWatchdog()
        session?.disconnect()
        connectedDevices.removeAll()
        statusMessage = "Disconnected"
    }

    // MARK: - Connection Health Watchdog
    private func startWatchdog() {
        stopWatchdog()
        lastReceivedTime = Date()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkConnectionHealth()
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func checkConnectionHealth() {
        guard !connectedDevices.isEmpty else { return }
        let elapsed = Date().timeIntervalSince(lastReceivedTime)
        if elapsed > staleTimeout {
            debugLog("Watchdog: no data for \(Int(elapsed))s, tearing down stale session", level: .warning)
            // Disconnecting fires `.notConnected`, which recreates the session
            // and restarts advertising for a clean reconnect.
            session?.disconnect()
        }
    }

    /// Recreates the session so the next invitation lands on a fresh, clean
    /// session rather than one left in a half-dead state by a previous drop.
    private func recreateSession() {
        session?.delegate = nil
        setupSession()
    }

    private func sendKeepaliveAck() {
        guard let session = session, !session.connectedPeers.isEmpty else { return }
        guard let data = RemoteCommand.keepaliveAck.rawValue.data(using: .utf8) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
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
                self.startWatchdog()

            case .connecting:
                self.debugLog("SESSION STATE: Connecting to \(peerID.displayName)", level: .network)
                self.sessionState = "Connecting to \(peerID.displayName)..."
                self.statusMessage = "Connecting to \(peerID.displayName)..."

            case .notConnected:
                self.debugLog("SESSION STATE: Not connected (was: \(peerID.displayName))", level: .warning)
                self.sessionState = "Not connected"
                self.connectedDevices.removeAll { $0 == peerID }
                if self.connectedDevices.isEmpty {
                    self.stopWatchdog()
                    // Recreate the session so the next invitation lands on a
                    // clean session instead of this half-dead one.
                    self.recreateSession()
                    self.statusMessage = "Waiting for iPhone to reconnect..."
                    if self.advertiser == nil && !self.userStoppedAdvertising {
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

        // Any inbound packet proves the link is alive — feed the watchdog.
        DispatchQueue.main.async {
            self.lastReceivedTime = Date()
        }

        // Keepalives are link-health probes, not user actions: reply and stop.
        if command == .keepalive {
            sendKeepaliveAck()
            return
        }
        if command == .keepaliveAck { return }

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

            // Advertising can fail transiently (e.g. no network yet at login).
            // Retry instead of leaving the Mac permanently invisible.
            guard !self.userStoppedAdvertising else { return }
            self.advertiseRetryWorkItem?.cancel()
            let retry = DispatchWorkItem { [weak self] in
                guard let self = self, !self.userStoppedAdvertising else { return }
                self.debugLog("Retrying advertiser after failure", level: .network)
                self.startAdvertising()
            }
            self.advertiseRetryWorkItem = retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: retry)
        }
    }
}
