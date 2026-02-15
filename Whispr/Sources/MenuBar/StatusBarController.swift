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

        appState.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.updateIcon()
            }
            .store(in: &cancellables)

        appState.$isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)
    }

    private func setupButton() {
        updateIcon()
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

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        if appState.isRecording {
            // Recording — red tinted mic
            let image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Recording")
            image?.isTemplate = false
            button.image = image
            button.contentTintColor = .systemRed
        } else if appState.isProcessing {
            // Processing — orange tinted
            let image = NSImage(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: "Processing")
            image?.isTemplate = false
            button.image = image
            button.contentTintColor = .systemOrange
        } else {
            // Idle — normal template icon
            let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Whispr")
            image?.isTemplate = true
            button.image = image
            button.contentTintColor = nil
        }
    }

    @objc private func openSettings() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
