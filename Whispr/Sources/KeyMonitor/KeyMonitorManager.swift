import CoreGraphics
import AppKit
import Carbon
import Foundation

class KeyMonitorManager {
    static let shared = KeyMonitorManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var appState: AppState?
    private var retryTimer: Timer?
    private var globalMonitor: Any?

    private init() {}

    func start(appState: AppState) {
        self.appState = appState
        setupGlobalHotkey()
    }

    private func setupGlobalHotkey() {
        // Use NSEvent global monitor for key combos — more reliable than CGEventTap
        // for modifier+key combinations on modern macOS
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Also monitor locally (when our own windows are focused)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }

        print("✅ Global hotkey monitor active. Press fn+Space or ⌥Space to toggle recording...")

        DispatchQueue.main.async { [weak self] in
            self?.appState?.statusMessage = "Ready — ⌥Space to record"
            self?.appState?.errorMessage = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = event.keyCode

        // Space = keyCode 49
        guard keyCode == 49 else { return }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Option+Space (⌥Space)
        if flags.contains(.option) {
            DispatchQueue.main.async { [weak self] in
                self?.toggleRecording()
            }
            return
        }

        // Also support fn+Space (if the system passes it through)
        if flags.contains(.function) {
            DispatchQueue.main.async { [weak self] in
                self?.toggleRecording()
            }
            return
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

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

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
