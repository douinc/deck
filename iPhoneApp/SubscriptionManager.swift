import StoreKit
import Foundation

/// Product ID for the yearly subscription
let subscriptionProductID = "com.dou.clicker_ios.subscription.yearly"

/// Manages subscription state, purchases, and trial tracking using StoreKit 2
@MainActor
@Observable
final class SubscriptionManager {
    private(set) var products: [Product] = []
    private(set) var status: AppSubscriptionStatus = .notDetermined
    private(set) var productLoadFailed = false

    private var transactionListener: Task<Void, Never>?
    private let trialTracker = TrialTracker()

    init() {
        #if SCREENSHOT_MODE
        // Force subscribed status for App Store screenshots
        status = .subscribed(expirationDate: Date.distantFuture)
        #else
        transactionListener = listenForTransactions()

        Task {
            async let products: Void = loadProducts()
            async let status: Void = updateSubscriptionStatus()
            _ = await (products, status)
        }
        #endif
    }

    /// Whether the user has access to premium features (trial or subscribed)
    var hasAccess: Bool {
        switch status {
        case .trial, .subscribed:
            return true
        case .notDetermined, .expired:
            return false
        }
    }

    /// Days remaining in trial, if applicable
    var trialDaysRemaining: Int? {
        if case .trial(let days) = status {
            return days
        }
        return nil
    }

    /// The yearly subscription product, if loaded
    var yearlyProduct: Product? {
        products.first { $0.id == subscriptionProductID }
    }

    /// Load available products from App Store
    func loadProducts() async {
        productLoadFailed = false
        do {
            products = try await Product.products(for: [subscriptionProductID])
            if products.isEmpty {
                print("No products found for ID: \(subscriptionProductID)")
                productLoadFailed = true
            }
        } catch {
            print("Failed to load products: \(error)")
            productLoadFailed = true
        }
    }

    /// Purchase a product
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await updateSubscriptionStatus()
                await transaction.finish()
                return true
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
        return false
    }

    /// Restore previous purchases
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    /// Update the current subscription status by checking entitlements and trial
    func updateSubscriptionStatus() async {
        // First, try using the subscription status API for more reliable checking
        if let product = yearlyProduct {
            do {
                let statuses = try await product.subscription?.status ?? []
                for status in statuses {
                    guard case .verified(_) = status.renewalInfo,
                          case .verified(let transaction) = status.transaction else {
                        continue
                    }

                    // Check if subscription is active
                    switch status.state {
                    case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                        if let expirationDate = transaction.expirationDate {
                            self.status = .subscribed(expirationDate: expirationDate)
                            return
                        }
                    default:
                        continue
                    }
                }
            } catch {
                // Fall through to entitlements check
            }
        }

        // Fallback: Check current entitlements
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productType == .autoRenewable,
               let expirationDate = transaction.expirationDate,
               expirationDate > Date() {
                status = .subscribed(expirationDate: expirationDate)
                return
            }
        }

        // No active subscription, check trial
        if trialTracker.isTrialActive {
            status = .trial(daysRemaining: trialTracker.daysRemaining)
        } else if !trialTracker.hasTrialStarted {
            // First launch - start trial
            trialTracker.startTrial()
            status = .trial(daysRemaining: 7)
        } else {
            status = .expired
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self?.updateSubscriptionStatus()
                    await transaction.finish()
                }
            }
        }
    }
}
