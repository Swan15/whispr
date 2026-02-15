import SwiftUI
import Combine

@main
struct WhisprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    let appState = AppState()

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
}
