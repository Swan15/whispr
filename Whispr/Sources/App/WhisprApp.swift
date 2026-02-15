import SwiftUI
import Combine

@main
struct WhisprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty WindowGroup — we manage everything via AppDelegate + menu bar
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    let appState = AppState()
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        // Close any auto-opened windows
        for window in NSApp.windows {
            window.close()
        }

        // Initialize menu bar
        statusBarController = StatusBarController(appState: appState)

        // Ensure support directory exists
        ExamplesStore.shared.ensureDirectoryExists()

        // Start key monitor
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
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 550, height: 500))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window
    }
}
