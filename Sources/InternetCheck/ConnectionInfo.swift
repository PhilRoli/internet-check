import Foundation
import Network
import SystemConfiguration

struct ConnectionInfo: Equatable {
    var serviceName: String?
    var interface: String?
    var ipAddress: String?

    static let none = ConnectionInfo()
}

protocol ConnectionInfoProviding {
    func current() -> ConnectionInfo
}

enum ConnectionFormat {
    static func line(_ info: ConnectionInfo) -> String {
        let parts = [info.serviceName, info.interface, info.ipAddress].compactMap { $0 }
        return parts.isEmpty ? "No connection" : parts.joined(separator: " · ")
    }
}

/// Resolves the primary IPv4 interface and the macOS network service (e.g. "Wi-Fi", "iPhone USB") behind it.
struct SystemConnectionInfoProvider: ConnectionInfoProviding {
    func current() -> ConnectionInfo {
        guard let store = SCDynamicStoreCreate(nil, "InternetCheck" as CFString, nil, nil),
              let global = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let bsdName = global["PrimaryInterface"] as? String
        else { return .none }
        return ConnectionInfo(serviceName: serviceName(for: bsdName), interface: bsdName, ipAddress: ipv4(of: bsdName))
    }

    private func serviceName(for bsdName: String) -> String? {
        guard let prefs = SCPreferencesCreate(nil, "InternetCheck" as CFString, nil),
              let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService] else { return nil }
        return services.first { service in
            SCNetworkServiceGetInterface(service).flatMap(SCNetworkInterfaceGetBSDName) as String? == bsdName
        }.flatMap { SCNetworkServiceGetName($0) as String? }
    }

    private func ipv4(of bsdName: String) -> String? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = ptr.pointee
            guard String(cString: entry.ifa_name) == bsdName, let addr = entry.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                return String(cString: host)
            }
        }
        return nil
    }
}

/// Fires `onChange` whenever the system network path changes (interface switch, link up/down).
final class NetworkChangeObserver {
    private let monitor = NWPathMonitor()
    private var isFirstUpdate = true

    init(onChange: @escaping @MainActor () -> Void) {
        monitor.pathUpdateHandler = { [weak self] _ in
            guard let self else { return }
            // The initial callback only reports the current state; it is not a change.
            if self.isFirstUpdate {
                self.isFirstUpdate = false
                return
            }
            Task { @MainActor in onChange() }
        }
        monitor.start(queue: DispatchQueue(label: "internet-check.path"))
    }

    func cancel() { monitor.cancel() }

    deinit { monitor.cancel() }
}
