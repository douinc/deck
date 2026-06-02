import Foundation

final class UpdateChecker: ObservableObject {
    @Published var availableUpdate: String?

    private let currentVersion: String
    private let lastCheckKey = "lastUpdateCheckDate"
    private let checkInterval: TimeInterval = 86400 // 24 hours

    init() {
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func checkIfNeeded() {
        if let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date,
           Date().timeIntervalSince(lastCheck) < checkInterval {
            return
        }

        Task {
            await check()
        }
    }

    private func check() async {
        guard let url = URL(string: "https://api.github.com/repos/douinc/deck/releases/latest") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else { return }

            let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            UserDefaults.standard.set(Date(), forKey: lastCheckKey)

            if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                await MainActor.run {
                    self.availableUpdate = latestVersion
                }
            }
        } catch {
            print("Update check failed: \(error.localizedDescription)")
        }
    }
}
