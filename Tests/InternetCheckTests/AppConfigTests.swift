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

final class BuiltInTargetTests: XCTestCase {
    func testBuiltInURLTargetsRequireTheExpectedReply() {
        let urls = AppConfig().targets.filter { $0.address.contains("://") }
        XCTAssertFalse(urls.isEmpty)
        XCTAssertTrue(urls.allSatisfy { $0.expectedStatus != nil }, "portal pages must not count as online")
    }

    func testCustomTargetsAcceptAnyAnswer() {
        let target = AppConfig.parseTarget("https://example.com")
        XCTAssertNil(target?.expectedStatus)
        XCTAssertNil(target?.expectedBody)
    }
}

final class ReviewFixTests: XCTestCase {
    func testNormalizeClampsHugeAndNonFiniteIntervals() {
        for (input, expected) in [(1e12, 3600.0), (Double.infinity, 10), (Double.nan, 10), (-Double.infinity, 10)] {
            var config = AppConfig()
            config.interval = input
            config.normalize()
            XCTAssertEqual(config.interval, expected, "\(input)")
        }
    }

    func testParseTargetRejectsPathsAndJunkWithoutScheme() {
        for text in ["example.com/path", "foo/bar", "!!!", "a?b", "user@host"] {
            XCTAssertNil(AppConfig.parseTarget(text), text)
        }
        XCTAssertNotNil(AppConfig.parseTarget("example.com:8080"))
    }

    func testNormalizeRefreshesStaleBuiltInsButKeepsEnabledFlagAndCustomTargets() throws {
        var config = AppConfig()
        let custom = try XCTUnwrap(AppConfig.parseTarget("9.9.9.9"))
        config.targets = [
            Target(id: "google", name: "Google", address: "https://old.example/204", isBuiltIn: true,
                   enabled: false, expectedStatus: 200, expectedBody: nil),
            Target(id: "gone", name: "Removed", address: "https://gone.example", isBuiltIn: true, enabled: true),
            custom
        ]
        config.normalize()
        let google = try XCTUnwrap(config.targets.first { $0.id == "google" })
        XCTAssertEqual(google.address, "https://connectivitycheck.gstatic.com/generate_204")
        XCTAssertEqual(google.expectedStatus, 204)
        XCTAssertFalse(google.enabled)
        XCTAssertNil(config.targets.first { $0.id == "gone" })
        XCTAssertNotNil(config.targets.first { $0.id == "apple-captive" }, "new built-ins are added")
        XCTAssertTrue(config.targets.contains(custom))
    }

    func testDecodingOldOrPartialConfigFallsBackPerField() throws {
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(#"{"interval": 30}"#.utf8))
        XCTAssertEqual(config.interval, 30)
        XCTAssertFalse(config.notificationsEnabled)
        XCTAssertEqual(config.targets.count, AppConfig.builtInTargets.count)
    }
}
