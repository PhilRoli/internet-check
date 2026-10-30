import AppKit
import MenuBarKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AppConfigStore()
    private let connectionProvider = SystemConnectionInfoProvider()
    private let statusBar = StatusBarController()
    private var poller: Poller?
    private var wakeObserver: NSObjectProtocol?
    private var networkObserver: NetworkChangeObserver?
    private var prefs: PreferencesWindowController?
    private let presenter = BannerNotificationPresenter()
    private lazy var notifications = NotificationManager(scheduler: UNUserNotificationCenter.current())

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make(appName: "InternetCheck")
        var config = store.load()
        config.normalize()
        let poller = Poller(prober: DefaultProber(), config: config)
        self.poller = poller
        UNUserNotificationCenter.current().delegate = presenter
        notifications.requestAuthorization()

        statusBar.connection = { [connectionProvider] in connectionProvider.current() }
        statusBar.onRefresh = { [unowned poller] in poller.refreshNow() }
        statusBar.onPreferences = { [unowned self, unowned poller] in
            let prefs = self.prefs ?? PreferencesWindowController(config: poller.config)
            prefs.onChange = { [unowned self, unowned poller] config in
                self.store.save(config)
                poller.config = config
            }
            self.prefs = prefs
            prefs.show()
        }
        poller.onTransition = { [unowned self, unowned poller] status in
            notifications.notify(status: status, enabled: poller.config.notificationsEnabled)
        }
        poller.onUpdate = { [unowned self] state in statusBar.render(state: state) }

        wakeObserver = observeWake { [unowned poller] in poller.didWake() }
        networkObserver = NetworkChangeObserver { [unowned poller] in poller.refreshNow() }
        poller.start()
    }
}
