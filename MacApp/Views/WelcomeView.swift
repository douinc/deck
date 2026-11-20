import SwiftUI
import CoreImage.CIFilterBuiltins

/// First-launch setup guide.
/// Walks a non-technical user through: what Deck is → allowing Deck to change
/// slides (Accessibility) → connecting their iPhone → where Deck lives.
/// Every step shows a picture of what they'll see and one clear next action.
struct WelcomeView: View {
    @ObservedObject var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: 0) {
            StepProgress(current: viewModel.currentStep)
                .padding(.top, 36)
                .padding(.bottom, 8)

            Group {
                switch viewModel.currentStep {
                case .introduction:
                    IntroductionStepView()
                case .accessibilityPermission:
                    PermissionStepView(viewModel: viewModel)
                case .connectiPhone:
                    ConnectiPhoneStepView(viewModel: viewModel)
                case .complete:
                    CompleteStepView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)

            Divider()

            // Navigation buttons
            HStack {
                if viewModel.currentStep != .introduction {
                    Button("Back") {
                        viewModel.previousStep()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.currentStep == .accessibilityPermission && !viewModel.hasPermission {
                    Text("Allow Deck first to continue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 8)
                }

                if viewModel.currentStep == .connectiPhone && viewModel.connectedDeviceName == nil {
                    Button("Skip for Now") {
                        viewModel.nextStep()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 12)
                }

                if viewModel.currentStep == .complete {
                    Button("Done") {
                        // Window closing is handled by onComplete callback in AppDelegate
                        viewModel.completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                } else if !(viewModel.currentStep == .connectiPhone && viewModel.connectedDeviceName == nil) {
                    Button("Continue") {
                        viewModel.nextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canProceed)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .frame(width: 560, height: 620)
        .onDisappear {
            viewModel.stopPermissionPolling()
        }
    }
}

// MARK: - Step Progress

private struct StepProgress: View {
    let current: WelcomeViewModel.WelcomeStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(WelcomeViewModel.WelcomeStep.allCases, id: \.self) { step in
                VStack(spacing: 6) {
                    Capsule()
                        .fill(step.rawValue <= current.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(height: 4)
                    Text(step.title)
                        .font(.caption2.weight(step == current ? .semibold : .regular))
                        .foregroundStyle(step == current ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Introduction Step

private struct IntroductionStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            HStack(spacing: 20) {
                DeviceBadge(symbol: "iphone")
                Image(systemName: "wave.3.right")
                    .font(.title)
                    .foregroundStyle(.blue)
                    .symbolEffect(.variableColor.iterative)
                DeviceBadge(symbol: "macbook")
            }

            VStack(spacing: 8) {
                Text("Welcome to Deck")
                    .font(.largeTitle.weight(.bold))
                Text("Change slides on this Mac by tapping your iPhone.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(icon: "hand.tap", title: "Tap to change slides",
                           description: "Big Next and Back buttons on your iPhone or Apple Watch")
                FeatureRow(icon: "rectangle.on.rectangle", title: "Works with your slides",
                           description: "Keynote, PowerPoint, Google Slides, PDF viewers and more")
                FeatureRow(icon: "clock", title: "About 1 minute to set up",
                           description: "We'll guide you through each step")
            }
            .padding(.horizontal, 60)

            Spacer()
        }
        .padding(.horizontal, 12)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct DeviceBadge: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 40, weight: .light))
            .frame(width: 84, height: 84)
            .background(Color.secondary.opacity(0.12), in: Circle())
    }
}

// MARK: - Permission Step

private struct PermissionStepView: View {
    @ObservedObject var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)

            if viewModel.needsRestart {
                StatusHeader(icon: "checkmark.circle.fill", color: .green,
                             title: "Allowed! Reopening Deck…",
                             subtitle: "Deck restarts by itself so it can change your slides. This guide will come right back.")
                ProgressView()
                    .controlSize(.small)
                Button("Reopen Now") {
                    viewModel.restartApp()
                }
                .buttonStyle(.link)
            } else if viewModel.hasPermission {
                StatusHeader(icon: "checkmark.circle.fill", color: .green,
                             title: "Deck can change slides",
                             subtitle: "Nice! Click Continue to connect your iPhone.")
            } else {
                StatusHeader(icon: "hand.raised.fill", color: .orange,
                             title: "Allow Deck to change slides",
                             subtitle: "Your Mac asks for your OK before any app can press keys for you.")

                // Picture of exactly what to switch on
                AccessibilitySettingsMock()

                VStack(alignment: .leading, spacing: 10) {
                    NumberedStep(number: 1, text: "Click **Open System Settings** below (and again if your Mac asks).")
                    NumberedStep(number: 2, text: "Find **Deck** in the list and turn its switch **on**.")
                    NumberedStep(number: 3, text: "Come back here — this page updates by itself.")
                }
                .padding(.horizontal, 70)

                Button {
                    viewModel.requestPermission()
                } label: {
                    Label("Open System Settings", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Label("Deck only presses the arrow keys for your slides. It never reads what you type.",
                      systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
        .onAppear {
            viewModel.startPermissionPolling()
        }
    }
}

/// A look-alike of the Accessibility list in System Settings with Deck's
/// switch highlighted, so people know what they're looking for.
private struct AccessibilitySettingsMock: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Privacy & Security › Accessibility")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 22, height: 22)
                Text("Deck").font(.callout.weight(.medium))
                Spacer()
                Toggle("", isOn: .constant(true))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .allowsHitTesting(false)
                Image(systemName: "arrow.left")
                    .foregroundStyle(.orange)
                    .font(.callout.weight(.bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.12))
        }
        .frame(width: 320)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.2)))
    }
}

// MARK: - Connect iPhone Step

private struct ConnectiPhoneStepView: View {
    @ObservedObject var viewModel: WelcomeViewModel

    /// Deck on the App Store, encoded as a QR code for the iPhone camera.
    private static let appStoreURL = "https://apps.apple.com/us/app/deck/id6758130180"

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)

            if let device = viewModel.connectedDeviceName {
                StatusHeader(icon: "checkmark.circle.fill", color: .green,
                             title: "Connected to \(device)!",
                             subtitle: "Your iPhone is ready to change slides on this Mac.")
            } else {
                StatusHeader(icon: "iphone.radiowaves.left.and.right", color: .blue,
                             title: "Connect your iPhone",
                             subtitle: "Keep this window open while you do this on your iPhone.")

                if viewModel.localNetworkDenied {
                    WarningBox(
                        text: "Your Mac is blocking Deck from the network, so your iPhone can't find it.",
                        buttonTitle: "Fix in System Settings…"
                    ) {
                        viewModel.openLocalNetworkSettings()
                    }
                }

                HStack(alignment: .center, spacing: 28) {
                    VStack(spacing: 8) {
                        QRCodeView(text: Self.appStoreURL)
                            .frame(width: 120, height: 120)
                        Text("Scan with your iPhone\ncamera to get Deck")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        NumberedStep(number: 1, text: "Get **Deck** on your iPhone (scan the code).")
                        NumberedStep(number: 2, text: "Put your iPhone on the **same Wi-Fi** as this Mac.")
                        NumberedStep(number: 3, text: "Open Deck and tap **\(viewModel.macDisplayName)**.")
                        NumberedStep(number: 4, text: "If asked to find devices on your network, tap **Allow**.")
                    }
                    .frame(maxWidth: 260)
                }

                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for your iPhone…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut, value: viewModel.connectedDeviceName)
    }
}

private struct QRCodeView: View {
    let text: String

    var body: some View {
        if let image = Self.makeImage(text) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.2))
        }
    }

    private static func makeImage(_ text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else { return nil }
        let rep = NSCIImageRep(ciImage: output)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}

// MARK: - Complete Step

private struct CompleteStepView: View {
    @ObservedObject var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            StatusHeader(icon: "checkmark.seal.fill", color: .green,
                         title: "You're all set!",
                         subtitle: "Deck now runs quietly in the background.")

            // Show exactly where Deck lives
            VStack(spacing: 6) {
                HStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "wifi")
                    Image(systemName: "battery.75percent")
                    Image("MenuBarIcon")
                        .renderingMode(.template)
                        .padding(5)
                        .overlay(Circle().stroke(Color.orange, lineWidth: 2))
                    Text("9:41").font(.callout)
                }
                .foregroundStyle(.primary.opacity(0.8))
                .padding(.horizontal, 14)
                .frame(width: 300, height: 34)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Spacer()
                    Label("Look for this at the top of your screen", systemImage: "arrow.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                .frame(width: 300)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("When you present:")
                    .font(.headline)
                NumberedStep(number: 1, text: "Open your slides and start the slideshow.")
                NumberedStep(number: 2, text: "Click on the slideshow once so it's in front.")
                NumberedStep(number: 3, text: "Open Deck on your iPhone and tap **Next**.")
            }
            .frame(width: 340, alignment: .leading)

            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Shared Pieces

private struct StatusHeader: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(color)
                .frame(width: 80, height: 80)
                .background(color.opacity(0.12), in: Circle())
            Text(title)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct NumberedStep: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor, in: Circle())
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WarningBox: View {
    let text: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(buttonTitle, action: action)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview {
    WelcomeView(viewModel: WelcomeViewModel())
}
