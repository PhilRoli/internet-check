import AppKit
import MenuBarKit

@MainActor
final class PreferencesWindowController: NSObject, NSTextFieldDelegate {
    var onChange: ((AppConfig) -> Void)?

    private var config: AppConfig
    private let loginItem: LoginItemController
    private lazy var window: NSWindow = {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "InternetCheck Preferences"
        window.isReleasedWhenClosed = false
        return window
    }()
    let addField = NSTextField()
    let addError = NSTextField(labelWithString: "")
    private let intervalField = NSTextField()

    init(config: AppConfig, loginItem: LoginItemController? = nil) {
        self.config = config
        self.loginItem = loginItem ?? LoginItemController()
        super.init()
    }

    func show() {
        rebuild()
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: Layout

    private func rebuild() {
        window.contentView?.subviews.forEach { $0.removeFromSuperview() }
        let stack = NSStackView(views: [
            PreferencesLayout.sectionLabel("Targets"), targetList(), addRow(), addError,
            PreferencesLayout.separator(width: 380),
            PreferencesLayout.sectionLabel("Interval"), intervalRow(),
            PreferencesLayout.separator(width: 380),
            checkbox("Notify when the connection changes", on: config.notificationsEnabled,
                     action: #selector(toggleNotifications(_:))),
            checkbox("Launch at login", on: loginItem.isEnabled, action: #selector(toggleLogin(_:))),
            PreferencesLayout.versionLabel()
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        PreferencesLayout.pinAndFit(stack, in: window)
    }

    private func targetList() -> NSView {
        let list = NSStackView(views: config.targets.map(targetRow))
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 4
        return list
    }

    private func targetRow(_ target: Target) -> NSView {
        let box = checkbox(target.name, on: target.enabled, action: #selector(toggleTarget(_:)))
        box.identifier = NSUserInterfaceItemIdentifier(target.id)
        let address = NSTextField(labelWithString: target.address)
        address.font = .systemFont(ofSize: 11)
        address.textColor = .secondaryLabelColor
        address.lineBreakMode = .byTruncatingMiddle
        address.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        var views: [NSView] = [box, address]
        if !target.isBuiltIn {
            let remove = NSButton(image: NSImage(systemSymbolName: "minus.circle", accessibilityDescription: "Remove")!,
                                  target: self, action: #selector(removeTarget(_:)))
            remove.isBordered = false
            remove.identifier = NSUserInterfaceItemIdentifier(target.id)
            views.append(remove)
        }
        let row = NSStackView(views: views)
        row.spacing = 8
        return row
    }

    private func addRow() -> NSView {
        addField.placeholderString = "URL or IP"
        addField.target = self
        addField.action = #selector(addTarget)
        addField.widthAnchor.constraint(equalToConstant: 260).isActive = true
        let button = NSButton(title: "Add", target: self, action: #selector(addTarget))
        addError.font = .systemFont(ofSize: 11)
        addError.textColor = .systemRed
        return NSStackView(views: [addField, button])
    }

    private func intervalRow() -> NSView {
        intervalField.stringValue = String(Int(config.interval))
        intervalField.delegate = self
        intervalField.alignment = .right
        intervalField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        return NSStackView(views: [PreferencesLayout.label("Check every"), intervalField,
                                   PreferencesLayout.label("seconds")])
    }

    private func checkbox(_ title: String, on: Bool, action: Selector) -> NSButton {
        let box = NSButton(checkboxWithTitle: title, target: self, action: action)
        box.state = on ? .on : .off
        return box
    }

    // MARK: Actions

    private func commit() {
        config.normalize()
        onChange?(config)
    }

    @objc private func toggleTarget(_ sender: NSButton) {
        guard let index = config.targets.firstIndex(where: { $0.id == sender.identifier?.rawValue }) else { return }
        config.targets[index].enabled = sender.state == .on
        commit()
    }

    @objc private func removeTarget(_ sender: NSButton) {
        config.targets.removeAll { $0.id == sender.identifier?.rawValue && !$0.isBuiltIn }
        commit()
        rebuild()
    }

    @objc func addTarget() {
        guard let target = AppConfig.parseTarget(addField.stringValue) else {
            addError.stringValue = "Enter a valid URL or IP address"
            return
        }
        guard !config.targets.contains(where: { $0.address.caseInsensitiveCompare(target.address) == .orderedSame })
        else {
            addError.stringValue = "Already in the list"
            return
        }
        config.targets.append(target)
        addField.stringValue = ""
        addError.stringValue = ""
        commit()
        rebuild()
    }

    @objc private func toggleNotifications(_ sender: NSButton) {
        config.notificationsEnabled = sender.state == .on
        commit()
    }

    @objc private func toggleLogin(_ sender: NSButton) {
        _ = loginItem.setEnabled(sender.state == .on)
        sender.state = loginItem.isEnabled ? .on : .off
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if let seconds = Double(intervalField.stringValue.trimmingCharacters(in: .whitespaces)) {
            config.interval = seconds
            commit()
        }
        intervalField.stringValue = String(Int(config.interval))
    }
}
