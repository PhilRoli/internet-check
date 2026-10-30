import XCTest
@testable import InternetCheck

final class MenuModelTests: XCTestCase {
    private func state(_ status: CheckState.Status, _ reachable: Int = 0, _ total: Int = 0) -> CheckState {
        CheckState(status: status, reachable: reachable, total: total, checkedAt: nil)
    }

    func testStatusLineForEachStatus() {
        XCTAssertEqual(MenuModel.statusLine(state(.unknown)), "Checking…")
        XCTAssertEqual(MenuModel.statusLine(state(.online, 3, 4)), "Online")
        XCTAssertEqual(MenuModel.statusLine(state(.offline, 0, 4)), "Offline")
        XCTAssertEqual(MenuModel.statusLine(state(.noTargets)), "No targets enabled")
    }

    func testReachabilityLineFormatsCounts() {
        XCTAssertEqual(MenuModel.reachabilityLine(state(.online, 2, 3)), "2/3 reachable")
        XCTAssertEqual(MenuModel.reachabilityLine(state(.offline, 0, 3)), "0/3 reachable")
    }

    func testReachabilityLineNilWhenUnknownOrNoTargets() {
        XCTAssertNil(MenuModel.reachabilityLine(state(.unknown)))
        XCTAssertNil(MenuModel.reachabilityLine(state(.noTargets)))
    }
}
