import Foundation
import Security

/// Tracks the 7-day trial period using Keychain storage (survives app deletion)
final class TrialTracker {
    private let trialDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let keychainKey = "com.dou.clicker-ios.trialStartDate"

    var trialStartDate: Date? {
        get { readFromKeychain() }
        set { saveToKeychain(newValue) }
    }

    var hasTrialStarted: Bool {
        trialStartDate != nil
    }

    var isTrialActive: Bool {
        guard let startDate = trialStartDate else { return false }
        return Date() < startDate.addingTimeInterval(trialDuration)
    }

    var daysRemaining: Int {
        guard let startDate = trialStartDate else { return 0 }
        let expirationDate = startDate.addingTimeInterval(trialDuration)
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return max(0, remaining)
    }

    func startTrial() {
        if trialStartDate == nil {
            trialStartDate = Date()
        }
    }

    // MARK: - Keychain Storage

    private func saveToKeychain(_ date: Date?) {
        // Delete existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Save new date if provided
        guard let date = date else { return }
        let data = "\(date.timeIntervalSince1970)".data(using: .utf8)!

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func readFromKeychain() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              let timestamp = Double(string) else {
            return nil
        }

        return Date(timeIntervalSince1970: timestamp)
    }
}
