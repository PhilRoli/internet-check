import Foundation
import Network
import SystemConfiguration

struct ConnectionInfo: Equatable {
    var serviceName: String?
    var interface: String?
    var ipAddress: String?
    /// The default route runs through a VPN tunnel; the other fields describe the physical link underneath.
    var viaVPN = false

    static let none = ConnectionInfo()
}

protocol ConnectionInfoProviding {
    func current() -> ConnectionInfo
}

enum ConnectionFormat {
    static func line(_ info: ConnectionInfo) -> String {
        let parts = [info.serviceName, info.interface, info.ipAddress].compactMap { $0 }
            + (info.viaVPN ? ["VPN"] : [])
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
        let services = networkServices()
        let serviceID = global["PrimaryService"] as? String
        guard Self.isVPN(interface: bsdName, serviceID: serviceID) else {
            let dynamicName = serviceID.flatMap(Self.displayName(forServiceID:))
            return ConnectionInfo(serviceName: dynamicName ?? name(of: bsdName, in: services), interface: bsdName,
                                  ipAddress: ipv4(of: bsdName))
        }
        guard Self.isTunnel(bsdName) else {
            return ConnectionInfo(serviceName: name(of: bsdName, in: services), interface: bsdName,
                                  ipAddress: ipv4(of: bsdName))
        }
        // VPN: report the first physical service (in the user's service order) that has an address.
        for (service, bsd) in services where !Self.isTunnel(bsd) {
            if let ip = ipv4(of: bsd) {
                return ConnectionInfo(serviceName: SCNetworkServiceGetName(service) as String?, interface: bsd,
                                      ipAddress: ip, viaVPN: true)
            }
        }
        return ConnectionInfo(serviceName: name(of: bsdName, in: services), interface: bsdName,
                              ipAddress: ipv4(of: bsdName), viaVPN: true)
    }

    static func isTunnel(_ bsdName: String) -> Bool {
        ["utun", "ppp", "ipsec", "tun", "tap"].contains { bsdName.hasPrefix($0) }
    }

    /// A tunnel is a VPN unless its service is a named dynamic one (e.g. `usbtether`). Real VPN services
    /// register under a UUID service ID.
    static func isVPN(interface: String, serviceID: String?) -> Bool {
        guard isTunnel(interface) else { return false }
        guard let serviceID else { return true }
        return UUID(uuidString: serviceID) != nil
    }

    /// Display name for dynamic (non-UUID) services that have no entry in the network preferences.
    static func displayName(forServiceID id: String) -> String? {
        guard UUID(uuidString: id) == nil else { return nil }
        return ["usbtether": "USB Tethering"][id] ?? id
    }

    /// Network services paired with their BSD interface names, in the user's service order.
    private func networkServices() -> [(SCNetworkService, String)] {
        guard let prefs = SCPreferencesCreate(nil, "InternetCheck" as CFString, nil),
              let all = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService] else { return [] }
        let order = SCNetworkSetCopyCurrent(prefs).flatMap { SCNetworkSetGetServiceOrder($0) as? [String] } ?? []
        let rank = { (service: SCNetworkService) in
            order.firstIndex(of: SCNetworkServiceGetServiceID(service) as String? ?? "") ?? Int.max
        }
        return all.sorted { rank($0) < rank($1) }.compactMap { service in
            SCNetworkServiceGetInterface(service).flatMap(SCNetworkInterfaceGetBSDName).map { (service, $0 as String) }
        }
    }

    private func name(of bsdName: String, in services: [(SCNetworkService, String)]) -> String? {
        services.first { $0.1 == bsdName }.flatMap { SCNetworkServiceGetName($0.0) as String? }
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
