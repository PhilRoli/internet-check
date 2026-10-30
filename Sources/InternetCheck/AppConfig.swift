import Foundation
import MenuBarKit

struct Target: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    /// URL string (`https://…`) or bare host / IP literal, optionally `:port`.
    var address: String
    var isBuiltIn: Bool
    var enabled: Bool
}

struct AppConfig: Codable, Equatable, DefaultInitializable {
    static let minInterval: TimeInterval = 2

    var targets: [Target] = AppConfig.builtInTargets
    var interval: TimeInterval = 10
    var notificationsEnabled = false

    static let builtInTargets: [Target] = [
        ("apple-captive", "Apple", "https://captive.apple.com/hotspot-detect.html"),
        ("apple-success", "Apple (www)", "https://www.apple.com/library/test/success.html"),
        ("cloudflare", "Cloudflare", "1.1.1.1"),
        ("google", "Google", "https://connectivitycheck.gstatic.com/generate_204")
    ].map { Target(id: $0.0, name: $0.1, address: $0.2, isBuiltIn: true, enabled: true) }

    mutating func normalize() {
        interval = max(interval, AppConfig.minInterval)
    }

    /// Builds a custom target from user input; nil when the text has no usable host.
    static func parseTarget(_ text: String) -> Target? {
        let address = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidAddress(address) else { return nil }
        return Target(id: UUID().uuidString, name: address, address: address, isBuiltIn: false, enabled: true)
    }

    private static func isValidAddress(_ address: String) -> Bool {
        guard !address.isEmpty, !address.contains(where: \.isWhitespace) else { return false }
        if address.contains("://") {
            guard let url = URL(string: address), let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme), let host = url.host else { return false }
            return !host.isEmpty
        }
        var v6 = in6_addr()
        if inet_pton(AF_INET6, address, &v6) == 1 { return true }
        let parts = address.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count <= 2, let host = parts.first, !host.isEmpty else { return false }
        if parts.count == 2 {
            guard let port = Int(parts[1]), (1...65535).contains(port) else { return false }
        }
        return true
    }
}

typealias AppConfigStore = JSONDefaultsStore<AppConfig>
