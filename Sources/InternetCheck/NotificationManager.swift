import MenuBarKit
import UserNotifications

@MainActor
final class NotificationManager {
    private let scheduler: NotificationScheduler

    init(scheduler: NotificationScheduler) {
        self.scheduler = scheduler
    }

    /// Asked at launch so the permission prompt is answered before the first notification.
    func requestAuthorization() {
        Task { [scheduler] in _ = try? await scheduler.requestAuthorization(options: [.alert, .sound]) }
    }

    func notify(status: CheckState.Status, enabled: Bool) {
        guard enabled else { return }
        let title: String
        switch status {
        case .offline: title = "Internet connection lost"
        case .online: title = "Back online"
        case .unknown, .noTargets: return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        scheduler.add(UNNotificationRequest(identifier: "internet-status", content: content, trigger: nil),
                      withCompletionHandler: nil)
    }
}
