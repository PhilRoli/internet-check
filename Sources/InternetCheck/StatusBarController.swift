import AppKit
import MenuBarKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    var onRefresh: (() -> Void)?
    var onPreferences: (() -> Void)?
    var connection: () -> ConnectionInfo = { .none }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let ticker = MenuOpenTicker()
    private var state = CheckState()
    private var connectionItem: NSMenuItem?

    override init() {
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        render(state: state)
    }

    /// Never use `contentTintColor`: on current macOS it renders the whole status item black.
    /// The offline dot is a palette-coloured, non-template image; online/unknown stay template images.
    func render(state: CheckState) {
        self.state = state
        guard let button = statusItem.button else { return }
        switch state.status {
        case .offline, .noTargets:
            let dot = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Offline")?
                .withSymbolConfiguration(.init(paletteColors: [.systemRed]))
            dot?.isTemplate = false
            button.image = dot
        case .online, .unknown:
            let wifi = NSImage(systemSymbolName: "wifi", accessibilityDescription: "Online")
            wifi?.isTemplate = true
            button.image = wifi
        }
        button.appearsDisabled = state.status == .unknown
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) { rebuild() }

    func menuWillOpen(_ menu: NSMenu) {
        ticker.start { [weak self] in
            guard let self else { return }
            self.connectionItem?.title = ConnectionFormat.line(self.connection())
        }
    }

    func menuDidClose(_ menu: NSMenu) { ticker.stop() }

    // MARK: Building

    private func rebuild() {
        menu.removeAllItems()
        menu.addItem(info(MenuModel.statusLine(state), weight: .semibold))
        if let line = MenuModel.reachabilityLine(state) { menu.addItem(info(line, secondary: true)) }
        let connectionItem = info(ConnectionFormat.line(connection()), secondary: true)
        self.connectionItem = connectionItem
        menu.addItem(connectionItem)
        menu.addItem(.separator())
        menu.addItem(.item("Check Now", action: #selector(refresh), key: "r", target: self))
        menu.addItem(.item("Preferences…", action: #selector(preferences), key: ",", target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func info(_ text: String, weight: NSFont.Weight = .regular, secondary: Bool = false) -> NSMenuItem {
        .info(NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: weight),
            .foregroundColor: secondary ? NSColor.secondaryLabelColor : NSColor.labelColor
        ]))
    }

    @objc private func refresh() { onRefresh?() }

    @objc private func preferences() { onPreferences?() }
}
