import Foundation

/// OpenRouter API service (OpenAI-compatible with extra headers)
final class OpenRouterService: LLMService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func sendMessage(
        messages: [LLMMessage],
        config: APIConfiguration
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: "\(config.effectiveBaseURL)/chat/completions") else {
                        continuation.finish(throwing: LLMError.invalidURL(config.effectiveBaseURL))
                        return
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("SwiftTavern", forHTTPHeaderField: "X-Title")
                    request.setValue("https://github.com/SwiftTavern", forHTTPHeaderField: "HTTP-Referer")

                    let params = config.generationParams
                    let body: [String: Any] = [
                        "model": config.model,
                        "messages": messages.map { msg -> [String: String] in
                            ["role": msg.role.rawValue, "content": msg.content]
                        },
                        "max_tokens": params.maxTokens,
                        "temperature": params.temperature,
                        "top_p": params.topP,
                        "frequency_penalty": params.frequencyPenalty,
                        "presence_penalty": params.presencePenalty,
                        "stream": true,
                    ]

                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: LLMError.invalidResponse(statusCode: statusCode, body: "OpenRouter error"))
                        return
                    }

                    for try await line in bytes.lines {
                        if let event = SSEParser.parseLine(line) {
                            switch event.type {
                            case .done:
                                continuation.finish()
                                return
                            case .data:
                                if let text = extractContent(from: event.data) {
                                    continuation.yield(text)
                                }
                            case .event:
                                break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func extractContent(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let delta = firstChoice["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }
        return content
    }
}
