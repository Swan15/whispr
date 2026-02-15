import AppKit

// Pure AppKit entry point — no SwiftUI App protocol
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
