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
    static let maxInterval: TimeInterval = 3600
    static let defaultInterval: TimeInterval = 10

    var targets: [Target] = AppConfig.builtInTargets
    var interval: TimeInterval = AppConfig.defaultInterval
    var notificationsEnabled = false

    /// Web targets only count with their known-good reply so captive-portal login pages read as offline.
    static let builtInTargets: [Target] = [
        builtIn("apple-captive", "Apple", "https://captive.apple.com/hotspot-detect.html",
                status: 200, body: "Success"),
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

    static func clampedInterval(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return defaultInterval }
        return min(max(value, minInterval), maxInterval)
    }

    /// Clamps the interval and refreshes built-in targets from the current list, keeping only their
    /// enabled flag, so saved configs never pin stale endpoints. Custom targets are kept as they are.
    mutating func normalize() {
        interval = Self.clampedInterval(interval)
        let enabled = Dictionary(targets.filter(\.isBuiltIn).map { ($0.id, $0.enabled) }) { first, _ in first }
        let builtIns = Self.builtInTargets.map { target -> Target in
            var target = target
            target.enabled = enabled[target.id] ?? true
            return target
        }
        targets = builtIns + targets.filter { !$0.isBuiltIn }
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
        guard parts.count <= 2, let host = parts.first, !host.isEmpty,
              host.range(of: "^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$", options: .regularExpression) != nil
        else { return false }
        if parts.count == 2 {
            guard let port = Int(parts[1]), (1...65535).contains(port) else { return false }
        }
        return true
    }
}

extension AppConfig {
    /// Per-field fallback so adding a field later never wipes a user's saved settings.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppConfig()
        targets = try container.decodeIfPresent([Target].self, forKey: .targets) ?? defaults.targets
        interval = try container.decodeIfPresent(TimeInterval.self, forKey: .interval) ?? defaults.interval
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled)
            ?? defaults.notificationsEnabled
    }
}

typealias AppConfigStore = JSONDefaultsStore<AppConfig>
