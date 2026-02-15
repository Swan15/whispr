import AVFoundation
import Foundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var isEngineRunning = false

    func startRecording() throws {
        // Clean up any previous state
        cleanupEngine()

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Get the input format — this can throw if no audio device
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Sanity check the format
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            throw AudioRecorderError.invalidFormat
        }

        // Create temp file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "whispr_recording_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)

        let audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: recordingFormat.sampleRate,
                AVNumberOfChannelsKey: recordingFormat.channelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        )

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, _ in
            do {
                try audioFile.write(from: buffer)
            } catch {
                print("Error writing audio buffer: \(error)")
            }
        }

        engine.prepare()

        // Retry engine start up to 3 times with short delays
        var lastError: Error?
        for attempt in 1...3 {
            do {
                try engine.start()
                lastError = nil
                break
            } catch {
                lastError = error
                print("Audio engine start attempt \(attempt) failed: \(error)")
                if attempt < 3 {
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }

        if let error = lastError {
            // Clean up on failure
            inputNode.removeTap(onBus: 0)
            try? FileManager.default.removeItem(at: fileURL)
            throw error
        }

        self.audioEngine = engine
        self.audioFile = audioFile
        self.recordingURL = fileURL
        self.isEngineRunning = true
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard let engine = audioEngine else {
            completion(nil)
            return
        }

        // Remove tap first, then stop
        engine.inputNode.removeTap(onBus: 0)

        if isEngineRunning {
            engine.stop()
            isEngineRunning = false
        }

        audioEngine = nil
        audioFile = nil

        let url = recordingURL
        recordingURL = nil
        completion(url)
    }

    private func cleanupEngine() {
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            if isEngineRunning {
                engine.stop()
                isEngineRunning = false
            }
        }
        audioEngine = nil
        audioFile = nil

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }
}

enum AudioRecorderError: LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid audio format — no microphone available or audio device not ready"
        }
    }
}
