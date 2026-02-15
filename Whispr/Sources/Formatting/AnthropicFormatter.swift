import Foundation

class AnthropicFormatter: FormattingProvider {
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
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build messages with few-shot examples
        var messages: [[String: String]] = []

        for example in examples.prefix(5) {
            messages.append(["role": "user", "content": example.input])
            messages.append(["role": "assistant", "content": example.output])
        }

        messages.append(["role": "user", "content": text])

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "system": systemPrompt,
            "messages": messages,
            "max_tokens": 2048,
            "temperature": 0.3
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
                   let content = json["content"] as? [[String: Any]],
                   let firstBlock = content.first,
                   let text = firstBlock["text"] as? String {
                    completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
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
