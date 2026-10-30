import AppKit
import MenuBarKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AppConfigStore()
    private let connectionProvider = SystemConnectionInfoProvider()
    private let statusBar = StatusBarController()
    private var poller: Poller?
    private var wakeObserver: NSObjectProtocol?
    private var networkObserver: NetworkChangeObserver?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make(appName: "InternetCheck")
        var config = store.load()
        config.normalize()
        let poller = Poller(prober: DefaultProber(), config: config)
        self.poller = poller

        statusBar.connection = { [connectionProvider] in connectionProvider.current() }
        statusBar.onRefresh = { [unowned poller] in poller.refreshNow() }
        poller.onUpdate = { [unowned self] state in statusBar.render(state: state) }

        wakeObserver = observeWake { [unowned poller] in poller.didWake() }
        networkObserver = NetworkChangeObserver { [unowned poller] in poller.refreshNow() }
        poller.start()
    }
}
