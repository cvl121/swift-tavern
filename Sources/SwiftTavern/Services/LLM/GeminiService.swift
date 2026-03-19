import Foundation

/// Google Gemini API service
final class GeminiService: LLMService {
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
                    guard let url = URL(string: "\(config.effectiveBaseURL)/v1beta/models/\(config.model):streamGenerateContent?alt=sse&key=\(config.apiKey)") else {
                        continuation.finish(throwing: LLMError.invalidURL(config.effectiveBaseURL))
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body = buildRequestBody(messages: messages, config: config)
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: LLMError.invalidResponse(statusCode: statusCode, body: "Gemini error"))
                        return
                    }

                    for try await line in bytes.lines {
                        if let event = SSEParser.parseLine(line),
                           case .data = event.type,
                           let text = extractContent(from: event.data) {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private func buildRequestBody(messages: [LLMMessage], config: APIConfiguration) -> [String: Any] {
        var contents: [[String: Any]] = []
        var systemInstruction: String?
        var lateSystemMessages: [String] = []
        var hasSeenConversation = false

        for msg in messages {
            if msg.role == .system {
                if hasSeenConversation {
                    lateSystemMessages.append(msg.content)
                } else {
                    systemInstruction = (systemInstruction ?? "") + msg.content + "\n"
                }
            } else {
                hasSeenConversation = true
                let role = msg.role == .user ? "user" : "model"
                contents.append([
                    "role": role,
                    "parts": [["text": msg.content]],
                ])
            }
        }

        // Append late system messages (reminders, post-history instructions) to the
        // system instruction so they reinforce at the end of context
        if !lateSystemMessages.isEmpty {
            let lateContent = lateSystemMessages.joined(separator: "\n\n")
            systemInstruction = (systemInstruction ?? "") + "\n\n---\n\n" + lateContent
        }

        if contents.isEmpty {
            contents.append([
                "role": "user",
                "parts": [["text": "Hello"]],
            ])
        }

        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "maxOutputTokens": config.generationParams.maxTokens,
                "temperature": config.generationParams.temperature,
                "topP": config.generationParams.topP,
                "topK": config.generationParams.topK,
            ] as [String: Any],
        ]

        if let sys = systemInstruction?.trimmingCharacters(in: .whitespacesAndNewlines), !sys.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": sys]],
            ]
        }

        return body
    }

    private func extractContent(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            return nil
        }
        return text
    }
}
