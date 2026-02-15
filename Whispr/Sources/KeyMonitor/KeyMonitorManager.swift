import AppKit
import Carbon
import Foundation

class KeyMonitorManager {
    static let shared = KeyMonitorManager()

    private weak var appState: AppState?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?

    private init() {}

    func start(appState: AppState) {
        self.appState = appState

        // Method 1: Carbon global hotkey (most reliable)
        registerCarbonHotkey()

        // Method 2: NSEvent monitors as fallback
        setupNSEventMonitors()

        print("✅ Hotkey registered. Press ⌥Space to toggle recording.")

        DispatchQueue.main.async { [weak self] in
            self?.appState?.statusMessage = "Ready — ⌥Space to record"
            self?.appState?.errorMessage = nil
        }
    }

    // MARK: - Carbon Global Hotkey (most reliable approach)

    private func registerCarbonHotkey() {
        // Register a Carbon event handler for hotkeys
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            DispatchQueue.main.async {
                KeyMonitorManager.shared.toggleRecording()
            }
            return noErr
        }

        var handlerRef: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &handlerRef)

        // Register ⌥Space (Option + Space)
        // Space = keyCode 49, Option = optionKey
        var hotKeyID = EventHotKeyID(signature: OSType(0x57535052), id: 1) // "WSPR"
        let modifiers: UInt32 = UInt32(optionKey)
        let keyCode: UInt32 = 49 // Space

        var hotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKey)

        if status == noErr {
            self.hotKeyRef = hotKey
            print("✅ Carbon hotkey registered: ⌥Space")
        } else {
            print("⚠️ Carbon hotkey registration failed: \(status)")
        }
    }

    // MARK: - NSEvent Monitors (fallback)

    private func setupNSEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Space = keyCode 49
        guard event.keyCode == 49 else { return }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ⌥Space
        if flags == .option {
            DispatchQueue.main.async { [weak self] in
                self?.toggleRecording()
            }
        }
    }

    // MARK: - Toggle

    private func toggleRecording() {
        guard let appState = appState else { return }

        if appState.isRecording {
            appState.stopRecordingAndProcess()
        } else if !appState.isProcessing {
            appState.startRecording()
        }
    }

    // MARK: - Cleanup

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let hotKey = hotKeyRef {
            UnregisterEventHotKey(hotKey)
            hotKeyRef = nil
        }
    }
}
