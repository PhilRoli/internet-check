import Foundation
import Network

protocol Prober: Sendable {
    func probe(_ target: Target, timeout: TimeInterval) async -> Bool
}

/// URL targets get an HTTP HEAD (any response counts); bare hosts / IPs get a TCP connect (443 unless `:port`).
struct DefaultProber: Prober {
    func probe(_ target: Target, timeout: TimeInterval) async -> Bool {
        if target.address.contains("://") {
            return await probeURL(target.address, timeout: timeout)
        }
        return await probeTCP(target.address, timeout: timeout)
    }

    private func probeURL(_ address: String, timeout: TimeInterval) async -> Bool {
        guard let url = URL(string: address) else { return false }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        do {
            let (_, response) = try await session.data(for: request)
            return response is HTTPURLResponse
        } catch {
            return false
        }
    }

    private func probeTCP(_ address: String, timeout: TimeInterval) async -> Bool {
        let (host, port) = Self.splitHostPort(address)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let queue = DispatchQueue(label: "internet-check.probe")
        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var finished = false
            func finish(_ result: Bool) {
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                connection.cancel()
                continuation.resume(returning: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true)
                case .failed, .cancelled: finish(false)
                case .waiting: finish(false)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { finish(false) }
        }
    }

    static func splitHostPort(_ address: String) -> (String, UInt16) {
        var v6 = in6_addr()
        if inet_pton(AF_INET6, address, &v6) == 1 { return (address, 443) }
        let parts = address.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count == 2, let port = UInt16(parts[1]) { return (String(parts[0]), port) }
        return (address, 443)
    }
}
