import SwiftUI
import Combine
import AVFoundation
import AppKit

class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var lastTranscription: String = ""
    @Published var lastFormatted: String = ""
    @Published var statusMessage: String = "Ready"
    @Published var errorMessage: String?

    // Settings
    @AppStorage("openai_api_key") var openAIAPIKey: String = ""
    @AppStorage("anthropic_api_key") var anthropicAPIKey: String = ""
    @AppStorage("formatting_provider") var formattingProvider: String = "openai"
    @AppStorage("formatting_system_prompt") var formattingSystemPrompt: String = AppState.defaultSystemPrompt
    @AppStorage("auto_paste_enabled") var autoPasteEnabled: Bool = true

    static let defaultSystemPrompt = """
    Format this transcribed speech into clean, well-structured text. \
    Fix grammar, remove filler words (um, uh, like), and maintain the speaker's intent. \
    If it's a message, keep it conversational. If it's technical/professional, format appropriately.
    """

    private var audioRecorder = AudioRecorder()
    private var cancellables = Set<AnyCancellable>()
    private var recordingStartTime: Date?

    /// Minimum recording duration in seconds — shorter recordings are treated as accidental
    private let minimumRecordingDuration: TimeInterval = 0.5

    init() {}

    // MARK: - Audio Feedback

    private func playStartSound() {
        NSSound(named: "Tink")?.play()
    }

    private func playStopSound() {
        NSSound(named: "Pop")?.play()
    }

    private func playCompleteSound() {
        NSSound(named: "Purr")?.play()
    }

    private func playErrorSound() {
        NSSound(named: "Basso")?.play()
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }

        isRecording = true
        statusMessage = "Recording..."
        errorMessage = nil
        recordingStartTime = Date()
        playStartSound()

        do {
            try audioRecorder.startRecording()
        } catch {
            isRecording = false
            recordingStartTime = nil
            statusMessage = "Error"
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            playErrorSound()

            // If it looks like a permission issue, guide the user
            if error.localizedDescription.contains("permission") || error.localizedDescription.contains("denied") {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Microphone Access Required"
                    alert.informativeText = "Whispr needs microphone access to record speech.\n\nGo to System Settings → Privacy & Security → Microphone and enable Whispr."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Open System Settings")
                    alert.addButton(withTitle: "OK")

                    if alert.runModal() == .alertFirstButtonReturn {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
    }

    func stopRecordingAndProcess() {
        guard isRecording else { return }
        isRecording = false

        // Check minimum recording duration
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            if duration < minimumRecordingDuration {
                // Too short — probably accidental, discard silently
                audioRecorder.stopRecording { url in
                    if let url = url {
                        try? FileManager.default.removeItem(at: url)
                    }
                }
                recordingStartTime = nil
                statusMessage = "Ready"
                return
            }
        }
        recordingStartTime = nil

        playStopSound()
        isProcessing = true
        statusMessage = "Processing..."

        audioRecorder.stopRecording { [weak self] audioFileURL in
            guard let self = self, let audioFileURL = audioFileURL else {
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    self?.statusMessage = "Error"
                    self?.errorMessage = "No audio recorded"
                    self?.playErrorSound()
                }
                return
            }

            self.processAudio(fileURL: audioFileURL)
        }
    }

    private func processAudio(fileURL: URL) {
        guard !openAIAPIKey.isEmpty else {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.statusMessage = "No API Key"
                self.errorMessage = "OpenAI API key not set. Open Settings to configure."
                self.playErrorSound()
            }
            return
        }

        DispatchQueue.main.async {
            self.statusMessage = "Transcribing..."
        }

        WhisperService.transcribe(fileURL: fileURL, apiKey: openAIAPIKey) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let transcription):
                DispatchQueue.main.async {
                    self.lastTranscription = transcription
                    self.statusMessage = "Formatting..."
                }
                self.formatTranscription(transcription)

            case .failure(let error):
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Error"
                    self.errorMessage = "Transcription failed: \(error.localizedDescription)"
                    self.playErrorSound()
                }
            }

            // Clean up audio file
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func formatTranscription(_ text: String) {
        let examples = ExamplesStore.shared.loadExamples()

        let provider: FormattingProvider
        if formattingProvider == "anthropic" && !anthropicAPIKey.isEmpty {
            provider = AnthropicFormatter(apiKey: anthropicAPIKey)
        } else {
            provider = OpenAIFormatter(apiKey: openAIAPIKey)
        }

        provider.format(
            text: text,
            systemPrompt: formattingSystemPrompt,
            examples: examples
        ) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isProcessing = false

                switch result {
                case .success(let formatted):
                    self.lastFormatted = formatted
                    self.statusMessage = "Done"
                    self.playCompleteSound()

                    // Copy to clipboard
                    ClipboardPaster.copyToClipboard(formatted)

                    // Auto-paste if enabled
                    if self.autoPasteEnabled {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            ClipboardPaster.simulatePaste()
                        }
                    }

                case .failure(let error):
                    self.statusMessage = "Error"
                    self.errorMessage = "Formatting failed: \(error.localizedDescription)"
                    self.playErrorSound()

                    // Fall back to raw transcription
                    self.lastFormatted = text
                    ClipboardPaster.copyToClipboard(text)
                    if self.autoPasteEnabled {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            ClipboardPaster.simulatePaste()
                        }
                    }
                }
            }
        }
    }
}
