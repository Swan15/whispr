import CoreGraphics
import AppKit
import Foundation

class KeyMonitorManager {
    static let shared = KeyMonitorManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var appState: AppState?
    private var fnKeyDown = false

    private init() {}

    func start(appState: AppState) {
        self.appState = appState

        // Check accessibility permission before trying to create the event tap
        if !AppState.checkAccessibilityPermission() {
            print("⚠️ Accessibility permission not granted. Requesting...")
            AppState.requestAccessibilityPermission()

            // Show a user-facing alert
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = """
                Whispr needs Accessibility access to detect the fn key and simulate paste.

                Please go to System Settings → Privacy & Security → Accessibility and enable Whispr.

                After granting permission, restart the app.
                """
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "OK")

                NSApp.activate(ignoringOtherApps: true)

                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            return
        }

        createEventTap()
    }

    private func createEventTap() {
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        // Store self pointer for callback
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }

                let monitor = Unmanaged<KeyMonitorManager>.fromOpaque(refcon).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    // Re-enable the tap
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }

                let flags = event.flags
                let fnPressed = flags.contains(.maskSecondaryFn)

                if fnPressed && !monitor.fnKeyDown {
                    // fn key pressed
                    monitor.fnKeyDown = true
                    DispatchQueue.main.async {
                        monitor.appState?.startRecording()
                    }
                } else if !fnPressed && monitor.fnKeyDown {
                    // fn key released
                    monitor.fnKeyDown = false
                    DispatchQueue.main.async {
                        monitor.appState?.stopRecordingAndProcess()
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: userInfo
        ) else {
            print("⚠️ Failed to create event tap. Accessibility permissions may not be granted.")
            print("   Go to System Settings > Privacy & Security > Accessibility and add Whispr.")

            DispatchQueue.main.async { [weak self] in
                self?.appState?.statusMessage = "No Accessibility Access"
                self?.appState?.errorMessage = "Failed to create event tap. Grant Accessibility permission and restart."
            }
            return
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("✅ Event tap created successfully. Listening for fn key...")
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
    }
}
