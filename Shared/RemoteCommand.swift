import Foundation

// MARK: - Commands sent from iPhone to Mac
enum RemoteCommand: String, Codable {
    case nextSlide = "next"
    case previousSlide = "previous"
    case startPresentation = "start"
    case endPresentation = "end"
    case blackScreen = "black"
    case keepalive = "keepalive"  // Used to maintain connection on hotspot

    var keyCode: UInt16? {
        switch self {
        case .nextSlide: return 124          // Right Arrow
        case .previousSlide: return 123       // Left Arrow
        case .startPresentation: return 36    // Return (to start slideshow)
        case .endPresentation: return 53      // Escape
        case .blackScreen: return 11          // 'B' key (PowerPoint black screen)
        case .keepalive: return nil           // No keystroke for keepalive
        }
    }
}

// MARK: - Service Configuration
struct RemoteServiceConfig {
    static let serviceType = "clickerremote"  // Must be 1-15 chars, lowercase, no spaces
    static let displayName = "Deck"
}
