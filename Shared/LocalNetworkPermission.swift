import Foundation

// Local Network privacy applies to the iPhone (iOS 14+) and the Mac (macOS 15+).
// It doesn't apply to the Watch, which talks to the phone over WatchConnectivity.
#if !os(watchOS)
import Network
import Combine

/// Best-effort detector for a *denied* Local Network permission.
///
/// MultipeerConnectivity gives no signal when Local Network access is off: the
/// browser/advertiser simply never finds anything, so the app sits on
/// "Searching for Mac..." forever. A Bonjour `NWBrowser` for our own service
/// type, however, lands in `.waiting(PolicyDenied)` (DNS error -65570) when
/// access has been denied. We use that to tell the user what's wrong.
///
/// Notes (see TN3179 and FB16077972):
/// - `.ready` is reported even when access is denied, so it is NOT proof of a
///   grant. We only ever positively detect *denial*.
/// - A browser that started before the user answered the prompt can keep
///   reporting stale state, so callers should `start()` again (which restarts
///   the probe) whenever the app returns to the foreground.
/// - Starting the probe also triggers the system's Local Network prompt early,
///   which is what we want on first launch.
final class LocalNetworkPermissionMonitor: ObservableObject {

    /// True once the probe has seen a PolicyDenied error during its current run.
    @Published private(set) var isDenied = false

    private var browser: NWBrowser?
    private var generation = 0
    private var deniedGeneration = -1
    private let queue = DispatchQueue(label: "com.dou.deck.local-network-probe")

    /// How long a run has to stay free of a denial before we clear a previous
    /// denial. Keeps the warning from flickering off/on on every restart.
    private let settleDelay: TimeInterval = 3.0

    /// DNS-SD error code for Local Network privacy denial (kDNSServiceErr_PolicyDenied).
    private static let policyDeniedCode: Int32 = -65570

    deinit {
        browser?.cancel()
    }

    /// Starts (or restarts) the probe. Must be called on the main thread.
    func start() {
        stop()
        generation += 1
        let runGeneration = generation

        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjour(type: "_\(RemoteServiceConfig.serviceType)._tcp", domain: nil),
            using: parameters
        )
        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .waiting(let error), .failed(let error):
                if Self.isPolicyDenied(error) {
                    DispatchQueue.main.async {
                        guard let self = self, self.generation == runGeneration else { return }
                        self.deniedGeneration = runGeneration
                        self.isDenied = true
                    }
                }
            default:
                break
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            // Actually seeing a Deck service proves access is allowed.
            guard !results.isEmpty else { return }
            DispatchQueue.main.async {
                guard let self = self, self.generation == runGeneration else { return }
                self.isDenied = false
            }
        }
        self.browser = browser
        browser.start(queue: queue)

        // If this run settles without reporting a denial, clear any stale one
        // (e.g. the user just turned Local Network back on in Settings).
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) { [weak self] in
            guard let self = self,
                  self.generation == runGeneration,
                  self.deniedGeneration != runGeneration else { return }
            self.isDenied = false
        }
    }

    func stop() {
        browser?.stateUpdateHandler = nil
        browser?.browseResultsChangedHandler = nil
        browser?.cancel()
        browser = nil
    }

    private static func isPolicyDenied(_ error: NWError) -> Bool {
        if case .dns(let code) = error, code == policyDeniedCode {
            return true
        }
        return false
    }
}
#endif
