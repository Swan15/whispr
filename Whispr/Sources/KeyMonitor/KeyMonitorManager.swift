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
        createEventTap()
    }

    private func createEventTap() {
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

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
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }

                let flags = event.flags
                let fnPressed = flags.contains(.maskSecondaryFn)

                if fnPressed && !monitor.fnKeyDown {
                    monitor.fnKeyDown = true
                    DispatchQueue.main.async {
                        monitor.appState?.startRecording()
                    }
                } else if !fnPressed && monitor.fnKeyDown {
                    monitor.fnKeyDown = false
                    DispatchQueue.main.async {
                        monitor.appState?.stopRecordingAndProcess()
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: userInfo
        ) else {
            // Event tap failed — this means Accessibility permission is not granted
            print("⚠️ Failed to create event tap. Accessibility permission not granted.")

            DispatchQueue.main.async { [weak self] in
                self?.appState?.statusMessage = "No Accessibility Access"
                self?.appState?.errorMessage = "Grant Accessibility permission and restart."

                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "Whispr needs Accessibility access to detect the fn key.\n\nGo to System Settings → Privacy & Security → Accessibility and enable Whispr, then restart the app."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "OK")

                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
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
