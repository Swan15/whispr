import AVFoundation
import Foundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    func startRecording() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

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

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            do {
                try audioFile.write(from: buffer)
            } catch {
                print("Error writing audio buffer: \(error)")
            }
        }

        engine.prepare()
        try engine.start()

        self.audioEngine = engine
        self.audioFile = audioFile
        self.recordingURL = fileURL
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil

        let url = recordingURL
        recordingURL = nil
        completion(url)
    }
}
