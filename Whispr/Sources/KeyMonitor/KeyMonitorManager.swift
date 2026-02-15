import CoreGraphics
import AppKit
import Foundation

class KeyMonitorManager {
    static let shared = KeyMonitorManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var appState: AppState?
    private var retryTimer: Timer?

    private init() {}

    func start(appState: AppState) {
        self.appState = appState
        attemptEventTap()
    }

    private func attemptEventTap() {
        retryTimer?.invalidate()
        retryTimer = nil

        // Listen for both flagsChanged (fn) and keyDown (space)
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
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

                // Check for fn + Space combo
                if type == .keyDown {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags

                    // keyCode 49 = Space, check if fn is held
                    if keyCode == 49 && flags.contains(.maskSecondaryFn) {
                        DispatchQueue.main.async {
                            monitor.toggleRecording()
                        }
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: userInfo
        ) else {
            print("⚠️ Event tap failed. Will retry every 2 seconds...")

            DispatchQueue.main.async { [weak self] in
                self?.appState?.statusMessage = "Waiting for Accessibility..."
                self?.appState?.errorMessage = "Grant Accessibility permission in System Settings."
            }

            DispatchQueue.main.async { [weak self] in
                self?.retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                    self?.attemptEventTap()
                }
            }
            return
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("✅ Event tap created. Listening for fn+Space...")

        DispatchQueue.main.async { [weak self] in
            self?.appState?.statusMessage = "Ready — fn+Space to record"
            self?.appState?.errorMessage = nil
        }
    }

    private func toggleRecording() {
        guard let appState = appState else { return }

        if appState.isRecording {
            appState.stopRecordingAndProcess()
        } else if !appState.isProcessing {
            appState.startRecording()
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
