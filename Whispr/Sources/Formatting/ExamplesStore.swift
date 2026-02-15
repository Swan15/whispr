import Foundation

class ExamplesStore {
    static let shared = ExamplesStore()

    private let directoryURL: URL
    private let fileURL: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        directoryURL = home.appendingPathComponent(".whispr")
        fileURL = directoryURL.appendingPathComponent("examples.json")
    }

    func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let emptyExamples: [FormattingExample] = []
            if let data = try? JSONEncoder().encode(emptyExamples) {
                try? data.write(to: fileURL)
            }
        }
    }

    func loadExamples() -> [FormattingExample] {
        guard let data = try? Data(contentsOf: fileURL),
              let examples = try? JSONDecoder().decode([FormattingExample].self, from: data) else {
            return []
        }
        return examples
    }

    func saveExamples(_ examples: [FormattingExample]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(examples) {
            try? data.write(to: fileURL)
        }
    }

    func addExample(input: String, output: String) {
        var examples = loadExamples()
        let example = FormattingExample(input: input, output: output)
        examples.append(example)
        saveExamples(examples)
    }

    func removeExample(id: String) {
        var examples = loadExamples()
        examples.removeAll { $0.id == id }
        saveExamples(examples)
    }
}
