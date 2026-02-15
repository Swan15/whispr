import AppKit
import Combine
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem
    private var appState: AppState
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupButton()
        setupMenu()

        // Observe recording state changes
        appState.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.updateIcon(isRecording: isRecording)
            }
            .store(in: &cancellables)

        appState.$isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isProcessing in
                if isProcessing {
                    self?.updateIconProcessing()
                }
            }
            .store(in: &cancellables)
    }

    private func setupButton() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Whispr")
            button.image?.isTemplate = true
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        let lastTranscription = NSMenuItem(title: "Last: (none)", action: nil, keyEquivalent: "")
        lastTranscription.isEnabled = false
        menu.addItem(lastTranscription)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Whispr", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Update menu items when state changes
        appState.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak statusMenuItem] message in
                statusMenuItem?.title = "Status: \(message)"
            }
            .store(in: &cancellables)

        appState.$lastFormatted
            .receive(on: DispatchQueue.main)
            .sink { [weak lastTranscription] text in
                let preview = text.isEmpty ? "(none)" : String(text.prefix(50))
                lastTranscription?.title = "Last: \(preview)"
            }
            .store(in: &cancellables)
    }

    private func updateIcon(isRecording: Bool) {
        if let button = statusItem.button {
            if isRecording {
                button.image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Recording")
                button.contentTintColor = .systemRed
            } else {
                button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Whispr")
                button.contentTintColor = nil
                button.image?.isTemplate = true
            }
        }
    }

    private func updateIconProcessing() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: "Processing")
            button.contentTintColor = .systemOrange
        }
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // macOS 14+ renamed showPreferencesWindow to showSettingsWindow
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
