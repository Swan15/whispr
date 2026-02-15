import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    let appState = AppState()
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only — no dock icon
        NSApp.setActivationPolicy(.accessory)

        // Initialize menu bar
        statusBarController = StatusBarController(appState: appState)

        // Ensure support directory exists
        ExamplesStore.shared.ensureDirectoryExists()

        // Start key monitor (will retry if permission not yet granted)
        KeyMonitorManager.shared.start(appState: appState)
    }

    func applicationWillTerminate(_ notification: Notification) {
        KeyMonitorManager.shared.stop()
    }

    func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(appState)

        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Whispr Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 550, height: 500))
        window.center()
        window.isReleasedWhenClosed = false

        self.settingsWindow = window

        // Temporarily show dock icon so the window can come to front
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // When window closes, hide dock icon again
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
