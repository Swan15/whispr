import SwiftUI
import Combine

@main
struct WhisprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar only app — no main window
        // Settings are opened via NSWindow in AppDelegate
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    let appState = AppState()
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

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
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 550, height: 500))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        self.settingsWindow = window

        // Temporarily become a regular app so the window actually shows
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // When the window closes, go back to accessory (menu bar only)
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            // Small delay to let the close animation finish
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self?.settingsWindow?.isVisible != true {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
}
