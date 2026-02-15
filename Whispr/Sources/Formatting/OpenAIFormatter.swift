import Foundation

class OpenAIFormatter: FormattingProvider {
    let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func format(
        text: String,
        systemPrompt: String,
        examples: [FormattingExample],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build messages with few-shot examples
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        for example in examples.prefix(5) {
            messages.append(["role": "user", "content": example.input])
            messages.append(["role": "assistant", "content": example.output])
        }

        messages.append(["role": "user", "content": text])

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 2048
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(FormattingError.noData))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
                    completion(.failure(FormattingError.invalidResponse(errorBody)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

enum FormattingError: LocalizedError {
    case noData
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data received from formatting API"
        case .invalidResponse(let body):
            return "Invalid response from formatting API: \(body)"
        }
    }
}
