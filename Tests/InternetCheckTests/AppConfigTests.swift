import XCTest
@testable import InternetCheck

final class AppConfigTests: XCTestCase {
    func testDefaultsHaveBuiltInTargetsEnabled() {
        let config = AppConfig()
        XCTAssertGreaterThanOrEqual(config.targets.count, 3)
        XCTAssertTrue(config.targets.allSatisfy { $0.isBuiltIn && $0.enabled })
    }

    func testDefaultIntervalIs10AndNotificationsOff() {
        let config = AppConfig()
        XCTAssertEqual(config.interval, 10)
        XCTAssertFalse(config.notificationsEnabled)
    }

    func testNormalizeClampsIntervalToMin() {
        for value in [0.0, -5.0] {
            var config = AppConfig()
            config.interval = value
            config.normalize()
            XCTAssertEqual(config.interval, 2)
        }
    }

    func testParseTargetRejectsEmptyAndHostless() {
        for text in ["", "  ", "http://"] {
            XCTAssertNil(AppConfig.parseTarget(text), text)
        }
    }

    func testParseTargetAcceptsIPAndURL() {
        for text in ["9.9.9.9", "example.com", "https://example.com/x"] {
            XCTAssertNotNil(AppConfig.parseTarget(text), text)
        }
    }

    func testConfigRoundTripsThroughJSON() throws {
        var config = AppConfig()
        config.interval = 30
        config.notificationsEnabled = true
        let data = try JSONEncoder().encode(config)
        XCTAssertEqual(try JSONDecoder().decode(AppConfig.self, from: data), config)
    }
}
