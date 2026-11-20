import AppKit

/// Quits Deck and opens it again.
///
/// macOS only applies a newly granted Accessibility permission to a fresh
/// process: until Deck relaunches, keystrokes are silently dropped even though
/// the iPhone/Watch connection looks fine. A tiny shell helper waits for this
/// process to fully exit before reopening the bundle, so `open` never just
/// re-activates the instance that's on its way out.
enum AppRelauncher {
    static func relaunch() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let bundlePath = Bundle.main.bundlePath

        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Bundle path is passed as $0 so spaces/quotes in it are safe.
        helper.arguments = [
            "-c",
            "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.1; done; /usr/bin/open \"$0\"",
            bundlePath
        ]
        do {
            try helper.run()
        } catch {
            print("Relaunch helper failed to start: \(error.localizedDescription)")
            return  // Don't quit if we can't come back.
        }
        NSApplication.shared.terminate(nil)
    }
}
