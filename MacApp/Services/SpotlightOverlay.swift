import AppKit

/// Dims every display except a circle around the cursor, so the audience's
/// eyes follow the pointer. Shown while the iPhone's pointer button is held
/// in spotlight mode.
final class SpotlightOverlay {
    static let shared = SpotlightOverlay()

    // MARK: - Tuning
    private let dimOpacity: CGFloat = 0.65
    private let radiusFraction: CGFloat = 0.13     // Of the display's height
    private let fadeDuration: TimeInterval = 0.15
    // The iPhone re-sends "on" twice a second while held. If those stop (dropped
    // connection, app killed mid-hold) the overlay lifts itself rather than
    // leaving the screen dimmed with nobody able to turn it off.
    private let timeout: TimeInterval = 2.0

    // MARK: - State
    private var windows: [NSWindow] = []
    private var timer: Timer?
    private var lastPing = Date.distantPast
    private var isActive = false

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.screensChanged()
        }
    }

    // MARK: - Public Methods

    func setActive(_ active: Bool) {
        if active {
            lastPing = Date()
            show()
        } else {
            hide()
        }
    }

    /// Any pointer traffic counts as proof the iPhone is still holding
    func keepAlive() {
        if isActive { lastPing = Date() }
    }

    // MARK: - Show / Hide

    private func show() {
        guard !isActive else { return }
        isActive = true

        if windows.isEmpty { buildWindows() }
        updateHoles()

        for window in windows {
            window.alphaValue = 0
            window.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            windows.forEach { $0.animator().alphaValue = 1 }
        }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func hide() {
        guard isActive else { return }
        isActive = false
        timer?.invalidate()
        timer = nil

        let fading = windows
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fadeDuration
            fading.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: { [weak self] in
            // Skip if the button was pressed again during the fade
            guard let self, !self.isActive else { return }
            fading.forEach { $0.orderOut(nil) }
        })
    }

    private func tick() {
        if Date().timeIntervalSince(lastPing) > timeout {
            hide()
            return
        }
        updateHoles()
    }

    // MARK: - Windows

    private func buildWindows() {
        windows = NSScreen.screens.map { screen in
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                                  backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true     // Clicks pass through to the slides
            window.isReleasedWhenClosed = false
            // Above full-screen slideshows, below the cursor itself
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.contentView = SpotlightView(
                frame: NSRect(origin: .zero, size: screen.frame.size),
                dimOpacity: dimOpacity
            )
            window.setFrame(screen.frame, display: false)
            return window
        }
    }

    private func screensChanged() {
        let wasActive = isActive
        timer?.invalidate()
        timer = nil
        isActive = false
        windows.forEach { $0.orderOut(nil) }
        windows = []
        if wasActive { show() }
    }

    private func updateHoles() {
        let cursor = NSEvent.mouseLocation   // Global, bottom-left origin
        for window in windows {
            guard let view = window.contentView as? SpotlightView else { continue }
            // Drawn on every display: a hole centered off this display is simply
            // clipped, and one straddling two displays shows on both.
            let center = window.convertPoint(fromScreen: cursor)
            view.setHole(center: center, radius: window.frame.height * radiusFraction)
        }
    }
}

// MARK: - Spotlight View
private final class SpotlightView: NSView {
    private let dim = CAShapeLayer()

    init(frame: NSRect, dimOpacity: CGFloat) {
        super.init(frame: frame)
        wantsLayer = true
        dim.fillRule = .evenOdd
        dim.fillColor = NSColor.black.withAlphaComponent(dimOpacity).cgColor
        layer?.addSublayer(dim)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setHole(center: CGPoint, radius: CGFloat) {
        let path = CGMutablePath()
        path.addRect(bounds)
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2))

        // No implicit animation: the hole must track the cursor exactly
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dim.frame = bounds
        dim.path = path
        CATransaction.commit()
    }
}
