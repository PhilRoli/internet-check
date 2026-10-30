import Foundation
import MenuBarKit

struct Target: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    /// URL string (`https://…`) or bare host / IP literal, optionally `:port`.
    var address: String
    var isBuiltIn: Bool
    var enabled: Bool
    /// When set, only this HTTP status counts as reachable (captive portals answer 200/302 for everything).
    var expectedStatus: Int?
    /// When set, the response body must contain this text (forces a GET instead of HEAD).
    var expectedBody: String?
}

struct AppConfig: Codable, Equatable, DefaultInitializable {
    static let minInterval: TimeInterval = 2

    var targets: [Target] = AppConfig.builtInTargets
    var interval: TimeInterval = 10
    var notificationsEnabled = false

    /// Web targets only count with their known-good reply so captive-portal login pages read as offline.
    static let builtInTargets: [Target] = [
        builtIn("apple-captive", "Apple", "https://captive.apple.com/hotspot-detect.html", status: 200, body: "Success"),
        builtIn("apple-success", "Apple (www)", "https://www.apple.com/library/test/success.html",
                status: 200, body: "Success"),
        builtIn("cloudflare", "Cloudflare", "https://one.one.one.one/cdn-cgi/trace", status: 200, body: "colo="),
        builtIn("google", "Google", "https://connectivitycheck.gstatic.com/generate_204", status: 204)
    ]

    private static func builtIn(_ id: String, _ name: String, _ address: String,
                                status: Int, body: String? = nil) -> Target {
        Target(id: id, name: name, address: address, isBuiltIn: true, enabled: true,
               expectedStatus: status, expectedBody: body)
    }

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
