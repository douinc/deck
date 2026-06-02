import SwiftUI
import StoreKit

/// URLs for legal documents required by App Store guidelines 3.1.2
private let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
private let privacyPolicyURL = URL(string: "https://douinc.github.io/deck/PRIVACY_POLICY.html")!

/// Paywall using Apple's SubscriptionStoreView for full guideline 3.1.2 compliance.
/// Automatically displays subscription title, price, length, and legal links.
struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: [subscriptionProductID]) {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image("DeckLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)

                    Text("Deck Pro")
                        .font(.largeTitle.bold())

                    Text("Control your presentations with ease")
                        .foregroundStyle(.secondary)
                }

                // Features
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(text: "Wireless slide control")
                    FeatureRow(text: "Presentation timer with haptics")
                    FeatureRow(text: "One-tap connection")
                }
                .padding(.horizontal, 8)

                // Legal links — functional links required by guideline 3.1.2(c)
                HStack(spacing: 16) {
                    Link("Terms of Use (EULA)", destination: termsOfUseURL)
                    Text("·").foregroundStyle(.secondary)
                    Link("Privacy Policy", destination: privacyPolicyURL)
                }
                .font(.footnote)
            }
            .padding(.top, 40)
        }
        .subscriptionStoreButtonLabel(.action)
        .storeButton(.visible, for: .restorePurchases)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success(_)) = result {
                await subscriptionManager.updateSubscriptionStatus()
                dismiss()
            }
        }
    }
}

/// Feature row with checkmark for paywall benefits list
struct FeatureRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
        }
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionManager())
}
