import AppKit
import MenuBarKit
import XCTest
@testable import InternetCheck

private struct FakeLoginItem: LoginItemManaging {
    var isEnabled = false
    var requiresApproval = false
    func register() throws {}
    func unregister() throws {}
}

@MainActor
final class PreferencesAndMenuTests: XCTestCase {
    private func makePrefs() -> PreferencesWindowController {
        PreferencesWindowController(config: AppConfig(), loginItem: LoginItemController(manager: FakeLoginItem()))
    }

    func testSuccessfulAddClearsFieldAndPreviousError() {
        let prefs = makePrefs()
        prefs.addField.stringValue = "!!!"
        prefs.addTarget()
        XCTAssertFalse(prefs.addError.stringValue.isEmpty)

        prefs.addField.stringValue = "9.9.9.9"
        prefs.addTarget()
        XCTAssertEqual(prefs.addError.stringValue, "")
        XCTAssertEqual(prefs.addField.stringValue, "")
    }

    func testConnectionTitleKeepsSecondaryStylingOnEveryUpdate() {
        let title = StatusBarController.infoText("Wi-Fi · en0", secondary: true)
        XCTAssertEqual(title.string, "Wi-Fi · en0")
        let attributes = title.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual(attributes[.foregroundColor] as? NSColor, .secondaryLabelColor)
        XCTAssertEqual((attributes[.font] as? NSFont)?.pointSize, 13)
    }
}
