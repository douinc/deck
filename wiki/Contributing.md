# Contributing

Thank you for your interest in contributing to Deck!

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/deck.git
   cd deck
   ```
3. Set up the development environment (see [[Getting-Started]])

## Development Workflow

### Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### Make Changes

1. Edit Swift source files directly
2. If changing build settings, edit `project.yml`
3. After editing `project.yml`, run `xcodegen generate`
4. **Never edit `Deck.xcodeproj` directly** — it's generated

### Test Your Changes

```bash
# Build both apps
just build-mac
just build-sim

# Run and test manually
just run-mac
```

### Commit Guidelines

Use conventional commit messages:

```
feat: add timer vibration pattern options
fix: resolve connection timeout on iOS 18
docs: update architecture diagram
refactor: extract connection logic to protocol
```

Prefixes:
- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation
- `refactor:` — Code refactoring
- `test:` — Tests
- `chore:` — Maintenance

### Submit a Pull Request

1. Push your branch:
   ```bash
   git push origin feature/your-feature-name
   ```
2. Open a PR on GitHub
3. Fill out the PR template
4. Wait for review

## Code Style

### Swift Style

- Use SwiftUI and modern Swift concurrency (`async`/`await`)
- Prefer `@MainActor` for UI-related classes
- Use `@Published` for observable state
- Follow Apple's [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes | PascalCase | `ConnectionManager` |
| Protocols | PascalCase | `CommandSender` |
| Functions | camelCase | `sendCommand()` |
| Variables | camelCase | `isConnected` |
| Constants | camelCase | `serviceType` |

### File Organization

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Protocol Conformance
```

## Project Structure Guidelines

### Adding New Features

1. **Shared code** → `Shared/`
2. **Mac-only code** → `MacApp/`
3. **iOS-only code** → `iPhoneApp/`

### Modifying Build Configuration

Edit `project.yml`, not Xcode project settings:

```yaml
targets:
  DeckMac:
    settings:
      base:
        YOUR_SETTING: value
```

Then regenerate:
```bash
xcodegen generate
```

## Areas for Contribution

### Good First Issues

- Documentation improvements
- UI polish and animations
- Accessibility improvements
- Localization

### Feature Ideas

- Additional key mappings (custom keys)
- Slide counter display
- Multiple Mac connections
- Widget for quick launch

### Known Issues

Check [GitHub Issues](https://github.com/douinc/deck/issues) for open bugs.

## Questions?

- Open a [Discussion](https://github.com/douinc/deck/discussions)
- File an [Issue](https://github.com/douinc/deck/issues)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
