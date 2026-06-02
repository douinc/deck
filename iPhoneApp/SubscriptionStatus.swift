import Foundation

/// Represents the current subscription state of the user
enum AppSubscriptionStatus: Equatable {
    /// Status hasn't been determined yet (loading)
    case notDetermined

    /// User is in free trial period
    case trial(daysRemaining: Int)

    /// User has an active subscription
    case subscribed(expirationDate: Date)

    /// Trial has expired and no active subscription
    case expired
}
