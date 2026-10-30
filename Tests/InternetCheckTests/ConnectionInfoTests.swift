import XCTest
@testable import InternetCheck

final class ConnectionInfoTests: XCTestCase {
    func testFormatFull() {
        let info = ConnectionInfo(serviceName: "Wi-Fi", interface: "en0", ipAddress: "192.168.1.5")
        XCTAssertEqual(ConnectionFormat.line(info), "Wi-Fi · en0 · 192.168.1.5")
    }

    func testFormatOmitsMissingParts() {
        XCTAssertEqual(ConnectionFormat.line(ConnectionInfo(serviceName: nil, interface: "en7", ipAddress: nil)), "en7")
        XCTAssertEqual(
            ConnectionFormat.line(ConnectionInfo(serviceName: "iPhone USB", interface: "en5", ipAddress: nil)),
            "iPhone USB · en5")
    }

    func testFormatNoneIsNoConnection() {
        XCTAssertEqual(ConnectionFormat.line(.none), "No connection")
    }

    func testSystemProviderDoesNotCrashAndIsConsistent() {
        let info = SystemConnectionInfoProvider().current()
        if info.interface == nil {
            XCTAssertNil(info.serviceName)
            XCTAssertNil(info.ipAddress)
        } else {
            XCTAssertFalse(info.interface!.isEmpty)
        }
    }

    func testFormatAppendsVPNTag() {
        let info = ConnectionInfo(serviceName: "Wi-Fi", interface: "en0", ipAddress: "192.168.1.5", viaVPN: true)
        XCTAssertEqual(ConnectionFormat.line(info), "Wi-Fi · en0 · 192.168.1.5 · VPN")
    }

    func testTunnelInterfaceDetection() {
        for name in ["utun4", "ppp0", "ipsec0", "tun0", "tap1"] {
            XCTAssertTrue(SystemConnectionInfoProvider.isTunnel(name), name)
        }
        for name in ["en0", "en7", "bridge0"] {
            XCTAssertFalse(SystemConnectionInfoProvider.isTunnel(name), name)
        }
    }
}
