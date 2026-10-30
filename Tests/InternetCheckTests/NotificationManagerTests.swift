import MenuBarKit
import UserNotifications
import XCTest
@testable import InternetCheck

private final class FakeScheduler: NotificationScheduler {
    var added: [UNNotificationRequest] = []
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?) {
        added.append(request)
    }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
}

@MainActor
final class NotificationManagerTests: XCTestCase {
    func testNoNotificationWhenDisabled() {
        let scheduler = FakeScheduler()
        NotificationManager(scheduler: scheduler).notify(status: .offline, enabled: false)
        XCTAssertTrue(scheduler.added.isEmpty)
    }

    func testOfflineAndOnlinePostDistinctMessages() {
        let scheduler = FakeScheduler()
        let manager = NotificationManager(scheduler: scheduler)
        manager.notify(status: .offline, enabled: true)
        manager.notify(status: .online, enabled: true)
        XCTAssertEqual(scheduler.added.map(\.content.title), ["Internet connection lost", "Back online"])
    }

    func testUnknownStatusPostsNothing() {
        let scheduler = FakeScheduler()
        let manager = NotificationManager(scheduler: scheduler)
        manager.notify(status: .unknown, enabled: true)
        manager.notify(status: .noTargets, enabled: true)
        XCTAssertTrue(scheduler.added.isEmpty)
    }
}
