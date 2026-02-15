import Foundation

protocol FormattingProvider {
    func format(
        text: String,
        systemPrompt: String,
        examples: [FormattingExample],
        completion: @escaping (Result<String, Error>) -> Void
    )
}

struct FormattingExample: Codable, Identifiable {
    var id: String = UUID().uuidString
    var input: String
    var output: String
    var createdAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id, input, output, createdAt
    }
}
