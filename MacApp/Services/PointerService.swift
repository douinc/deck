import Foundation
import CoreGraphics

/// Mouse injection service
/// Moves the cursor and clicks on behalf of the iPhone's pointer mode
final class PointerService {
    static let shared = PointerService()

    private let permissionService: PermissionService

    // Sub-point remainder carried between moves. The system reports the cursor
    // at whole points, so without this slow, precise motion would round to zero.
    private var residual = CGPoint.zero

    init(permissionService: PermissionService = .shared) {
        self.permissionService = permissionService
    }

    // MARK: - Public Methods

    /// Applies a pointer message from the iPhone
    /// - Returns: false if accessibility permission is missing
    @discardableResult
    func handle(_ message: PointerMessage) -> Bool {
        // The overlay needs no permission, and "off" must always get through
        if case .spotlight(let on) = message {
            SpotlightOverlay.shared.setActive(on)
            return true
        }
        SpotlightOverlay.shared.keepAlive()

        guard permissionService.hasAccessibilityPermission else { return false }

        switch message {
        case .move(let dx, let dy):
            move(dx: dx, dy: dy)
        case .click:
            click()
        case .spotlight:
            break
        }
        return true
    }

    // MARK: - Private Methods

    private var cursorLocation: CGPoint {
        // Global display coordinates, origin at the top-left of the main display
        CGEvent(source: nil)?.location ?? .zero
    }

    private func move(dx: Double, dy: Double) {
        residual.x += dx
        residual.y += dy
        let stepX = residual.x.rounded(.towardZero)
        let stepY = residual.y.rounded(.towardZero)
        guard stepX != 0 || stepY != 0 else { return }
        residual.x -= stepX
        residual.y -= stepY

        let current = cursorLocation
        let target = clamp(CGPoint(x: current.x + stepX, y: current.y + stepY), from: current)

        let source = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                            mouseCursorPosition: target, mouseButton: .left)
        // Some apps read the deltas rather than the absolute position
        event?.setIntegerValueField(.mouseEventDeltaX, value: Int64(stepX))
        event?.setIntegerValueField(.mouseEventDeltaY, value: Int64(stepY))
        event?.post(tap: .cghidEventTap)
    }

    private func click() {
        let location = cursorLocation
        let source = CGEventSource(stateID: .hidSystemState)

        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                           mouseCursorPosition: location, mouseButton: .left)
        down?.post(tap: .cghidEventTap)

        usleep(10000) // 10ms

        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                         mouseCursorPosition: location, mouseButton: .left)
        up?.post(tap: .cghidEventTap)
    }

    /// Keeps the cursor on a display. Moving between displays is allowed; moving
    /// off every display clamps to the edge of the display the cursor was on.
    private func clamp(_ point: CGPoint, from origin: CGPoint) -> CGPoint {
        var count: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetActiveDisplayList(UInt32(displays.count), &displays, &count) == .success, count > 0 else {
            return point
        }
        let bounds = displays.prefix(Int(count)).map { CGDisplayBounds($0) }

        if bounds.contains(where: { $0.contains(point) }) { return point }

        let home = bounds.first(where: { $0.contains(origin) }) ?? CGDisplayBounds(CGMainDisplayID())
        return CGPoint(
            x: min(max(point.x, home.minX), home.maxX - 1),
            y: min(max(point.y, home.minY), home.maxY - 1)
        )
    }
}
