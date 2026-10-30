import AppKit
import MenuBarKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make(appName: "InternetCheck")
    }
}

MainActor.assumeIsolated { runMenuBarApp(AppDelegate()) }
