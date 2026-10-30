import Network
import XCTest
@testable import InternetCheck

private final class LocalServer {
    let listener: NWListener
    private(set) var port: UInt16 = 0

    init(httpReply: Bool) throws {
        listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { conn in
            conn.start(queue: .global())
            guard httpReply else { return }
            conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { _, _, _, _ in
                let reply = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                conn.send(content: Data(reply.utf8), completion: .contentProcessed { _ in conn.cancel() })
            }
        }
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { if case .ready = $0 { ready.signal() } }
        listener.start(queue: .global())
        _ = ready.wait(timeout: .now() + 2)
        port = listener.port?.rawValue ?? 0
    }

    deinit { listener.cancel() }
}

private func target(_ address: String) -> Target {
    Target(id: address, name: address, address: address, isBuiltIn: false, enabled: true)
}

final class ProberTests: XCTestCase {
    func testTCPTargetReachableWhenListening() async throws {
        let server = try LocalServer(httpReply: false)
        let ok = await DefaultProber().probe(target("127.0.0.1:\(server.port)"), timeout: 2)
        XCTAssertTrue(ok)
    }

    func testTCPTargetUnreachableWhenClosed() async throws {
        let server = try LocalServer(httpReply: false)
        let port = server.port
        server.listener.cancel()
        try await Task.sleep(nanoseconds: 100_000_000)
        let ok = await DefaultProber().probe(target("127.0.0.1:\(port)"), timeout: 2)
        XCTAssertFalse(ok)
    }

    func testTimeoutReturnsFalseWithinBound() async {
        let start = Date()
        let ok = await DefaultProber().probe(target("10.255.255.1"), timeout: 0.5)
        XCTAssertFalse(ok)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
    }

    func testURLTargetAnyHTTPStatusIsReachable() async throws {
        let server = try LocalServer(httpReply: true)
        let ok = await DefaultProber().probe(target("http://127.0.0.1:\(server.port)/x"), timeout: 2)
        XCTAssertTrue(ok)
    }
}
