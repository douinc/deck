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
