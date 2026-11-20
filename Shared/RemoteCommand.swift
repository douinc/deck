import Foundation
#if canImport(MultipeerConnectivity)
import MultipeerConnectivity
#endif

// MARK: - Commands sent from iPhone to Mac
enum RemoteCommand: String, Codable {
    case nextSlide = "next"
    case previousSlide = "previous"
    case startPresentation = "start"
    case endPresentation = "end"
    case blackScreen = "black"
    case keepalive = "keepalive"          // iPhone → Mac liveness probe (also keeps hotspot NAT warm)
    case keepaliveAck = "keepalive_ack"   // Mac → iPhone reply, lets the phone detect a half-open link

    var keyCode: UInt16? {
        switch self {
        case .nextSlide: return 124          // Right Arrow
        case .previousSlide: return 123       // Left Arrow
        case .startPresentation: return 36    // Return (to start slideshow)
        case .endPresentation: return 53      // Escape
        case .blackScreen: return 11          // 'B' key (PowerPoint black screen)
        case .keepalive: return nil           // No keystroke for keepalive
        case .keepaliveAck: return nil        // No keystroke for keepalive ack
        }
    }
}

// MARK: - Pointer messages sent from iPhone to Mac
// Sent over the same MCSession data channel as RemoteCommand, as "ptr:"-prefixed
// strings. Older Mac builds fail to decode them as a RemoteCommand and drop them,
// so a new iPhone build stays compatible with an old Mac (minus the pointer).
enum PointerMessage: Equatable {
    case move(dx: Double, dy: Double)   // Relative cursor motion in points (y grows downward)
    case click                          // Left click at the current cursor position

    private static let prefix = "ptr:"

    var wireString: String {
        switch self {
        case .move(let dx, let dy):
            return String(format: "\(Self.prefix)m:%.1f,%.1f", dx, dy)
        case .click:
            return "\(Self.prefix)click"
        }
    }

    init?(wireString: String) {
        guard wireString.hasPrefix(Self.prefix) else { return nil }
        let body = wireString.dropFirst(Self.prefix.count)
        if body == "click" {
            self = .click
            return
        }
        guard body.hasPrefix("m:") else { return nil }
        let parts = body.dropFirst(2).split(separator: ",")
        guard parts.count == 2, let dx = Double(parts[0]), let dy = Double(parts[1]) else { return nil }
        self = .move(dx: dx, dy: dy)
    }
}

// MARK: - Service Configuration
struct RemoteServiceConfig {
    static let serviceType = "clickerremote"  // Must be 1-15 chars, lowercase, no spaces
    static let displayName = "Deck"
}

// MARK: - Persistent Peer Identity
// MultipeerConnectivity is unavailable on watchOS, so this helper is compiled
// only for the Mac and iPhone targets that actually own an MCSession.
//
// Apple recommends reusing a single MCPeerID instance rather than recreating one
// on every launch: a fresh MCPeerID with the same display name is treated as a
// *different* peer, which produces phantom/duplicate peers and confuses
// reconnection-by-name. Persisting it across launches keeps identity stable.
#if canImport(MultipeerConnectivity)
extension RemoteServiceConfig {
    private static let peerIDDataKey = "DeckCachedPeerIDData"
    private static let peerIDNameKey = "DeckCachedPeerIDName"

    static func persistentPeerID(displayName: String) -> MCPeerID {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: peerIDNameKey) == displayName,
           let data = defaults.data(forKey: peerIDDataKey),
           let peerID = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data) {
            return peerID
        }

        let peerID = MCPeerID(displayName: displayName)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: peerID, requiringSecureCoding: true) {
            defaults.set(data, forKey: peerIDDataKey)
            defaults.set(displayName, forKey: peerIDNameKey)
        }
        return peerID
    }
}
#endif
