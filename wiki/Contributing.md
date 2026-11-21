# Contributing

Thanks for your interest in Deck.

## Getting started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/deck.git
   cd deck
   ```
3. Set up the development environment: [[Getting-Started]]

## Workflow

### Create a branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### Make changes

1. Edit Swift source files directly
2. For build settings, targets or Info.plist keys, edit `project.yml`
3. After editing `project.yml`, run `just generate`
4. Never edit `Deck.xcodeproj`; it is generated and git-ignored

### Test your changes

There is no automated test suite yet, so test by hand on real devices where it matters.

```bash
just build-mac
just build-sim
just run-mac
```

| If you changed | Check |
|----------------|-------|
| Connection code | First-run discovery, reconnect after the Mac sleeps, reconnect after backgrounding the iPhone, Disconnect |
| The remote layout | Both holding hands, a small and a large iPhone, Arrange Buttons, a saved custom layout |
| The timer | A limit and no limit, each color threshold, overtime, the Live Activity |
| The pointer | Hold, tap to click, Spotlight on two displays, letting go mid-move |
| The wire protocol | An old Mac build with a new iPhone build, and the reverse |
| The Mac app | A fresh Accessibility grant (automatic relaunch), Pause and Resume, the setup guide |
| The watch app | Double Tap and Wrist Flick modes, the Crown, the connect guide |

The simulator launch arguments in [[Getting-Started]] make layout work much faster.

### Commit messages

Use conventional commit prefixes:

```
feat: add pointer speed setting
fix: reconnect after the Mac wakes from sleep
docs: update architecture diagram
refactor: extract arc geometry into ArcLayout
```

| Prefix | For |
|--------|-----|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation |
| `refactor:` | Restructuring without behavior change |
| `test:` | Tests |
| `build:` | Build system and release tooling |
| `chore:` | Maintenance |

### Open a pull request

1. Push your branch
2. Open a pull request against `main`
3. Describe what changed and how you tested it
4. Wait for review. Pull requests are also reviewed automatically by the Claude Code review workflow.

## Code style

### Swift

- SwiftUI for all UI
- `ObservableObject` with `@Published` for long-lived managers; `@Observable` is used for `SubscriptionManager`
- Delegate callbacks from MultipeerConnectivity and WatchConnectivity arrive off the main thread; hop to the main queue before touching published state
- Follow Apple's [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Comment the reason, not the mechanics. The connection managers are a good model: each workaround says which failure it prevents.

### User-facing text

Deck's setup screens are written for people who have never used a remote app. Keep that voice:

- Plain words: "Allow Deck to change slides", not "Grant Accessibility permission"
- One clear next action per screen
- Say where to look: "the Deck icon at the top-right of your Mac's screen"
- Technical details go in diagnostics, not in the main flow

### File organization

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
```

## Where code goes

| Code | Directory |
|------|-----------|
| Shared by more than one app | `Shared/` |
| Mac only | `MacApp/` (`Services/`, `ViewModels/`, `Views/`) |
| iPhone only | `iPhoneApp/` |
| Watch only | `WatchApp/` |
| Lock Screen and Dynamic Island | `LiveActivityWidget/` |

A file in `Shared/` compiles into the Mac, iPhone and watch targets. Guard anything unavailable on watchOS, as `RemoteCommand.swift` does for MultipeerConnectivity.

## Design consistency

The remote's arc geometry and timer colors are repeated in the landing page (`index.html`) and the App Store panels (`marketing/appstore/`). If you change `ArcLayout` or `TimerTint`, update those too. See [[Building]] for how the marketing assets are rendered.

## Documentation

- This wiki's source is `wiki/` in the repository. Edit it there; it syncs to GitHub on merge.
- Update the wiki, the README and the support page (`support/index.html`) when behavior that users see changes.
- Use `[[Page-Name]]` for links between wiki pages and Mermaid for diagrams.

## Ideas and issues

- [[Feature-Ideas]] lists what could come next
- [GitHub Issues](https://github.com/douinc/deck/issues) lists open bugs

## License

By contributing, you agree that your contributions are licensed under the MIT License.
