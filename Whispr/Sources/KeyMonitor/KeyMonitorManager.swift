import CoreGraphics
import AppKit
import Foundation

class KeyMonitorManager {
    static let shared = KeyMonitorManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var appState: AppState?
    private var fnKeyDown = false
    private var retryTimer: Timer?

    private init() {}

    func start(appState: AppState) {
        self.appState = appState
        attemptEventTap()
    }

    private func attemptEventTap() {
        // Stop any existing retry timer
        retryTimer?.invalidate()
        retryTimer = nil

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
            // Event tap creation failed — no accessibility permission
            print("⚠️ Event tap failed. Will retry every 2 seconds...")

            DispatchQueue.main.async { [weak self] in
                self?.appState?.statusMessage = "Waiting for Accessibility..."
                self?.appState?.errorMessage = "Grant Accessibility permission in System Settings. Whispr will detect it automatically."
            }

            // Retry every 2 seconds until permission is granted
            DispatchQueue.main.async { [weak self] in
                self?.retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                    self?.attemptEventTap()
                }
            }
            return
        }

        // Success!
        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("✅ Event tap created. Listening for fn key...")

        DispatchQueue.main.async { [weak self] in
            self?.appState?.statusMessage = "Ready"
            self?.appState?.errorMessage = nil
        }
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil

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
