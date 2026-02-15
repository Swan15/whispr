import AppKit
import CoreGraphics

struct ClipboardPaster {
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func simulatePaste() {
        // Small delay to ensure clipboard is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            pasteViaCGEvent()
        }
    }

    private static func pasteViaCGEvent() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code 9 = 'V'
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            print("⚠️ Failed to create CGEvent for paste — trying AppleScript fallback")
            pasteViaAppleScript()
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private static func pasteViaAppleScript() {
        let script = NSAppleScript(source: """
            tell application "System Events"
                keystroke "v" using command down
            end tell
        """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        if let error = error {
            print("⚠️ AppleScript paste failed: \(error)")
        }
    }
}
