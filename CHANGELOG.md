# Changelog

## v1.7

- Removed CoreMotion wrist flick gesture detection from Apple Watch app due to unreliable production behavior
- Added double-tap gesture support (`handGestureShortcut(.primaryAction)`) for advancing slides on watchOS 11+ (Apple Watch Series 9+ / Ultra 2)
- Note: Double-tap requires the watch display to be active (wrist raised); it does not work in always-on / luminance-reduced state
