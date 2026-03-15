import Foundation

/// OpenAI Chat Completions API service
/// Also serves as the base for OpenAI-compatible APIs (Ollama, OpenRouter)
final class OpenAIService: LLMService {
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
                    let request = try buildRequest(messages: messages, config: config, stream: true)
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: LLMError.invalidResponse(statusCode: 0, body: "Not HTTP"))
                        return
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        var body = ""
                        for try await line in bytes.lines {
                            body += line
                        }
                        continuation.finish(throwing: LLMError.invalidResponse(statusCode: httpResponse.statusCode, body: body))
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

    func sendMessageComplete(
        messages: [LLMMessage],
        config: APIConfiguration
    ) async throws -> String {
        let request = try buildRequest(messages: messages, config: config, stream: false)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.invalidResponse(statusCode: statusCode, body: body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.noContent
        }

        return content
    }

    // MARK: - Private

    func buildRequest(messages: [LLMMessage], config: APIConfiguration, stream: Bool) throws -> URLRequest {
        guard let url = URL(string: "\(config.effectiveBaseURL)/chat/completions") else {
            throw LLMError.invalidURL(config.effectiveBaseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let params = config.generationParams
        var body: [String: Any] = [
            "model": config.model,
            "messages": messages.map { msg -> [String: String] in
                ["role": msg.role.rawValue, "content": msg.content]
            },
            "max_tokens": params.maxTokens,
            "temperature": params.temperature,
            "top_p": params.topP,
            "frequency_penalty": params.frequencyPenalty,
            "presence_penalty": params.presencePenalty,
            "stream": stream,
        ]

        if !params.stopSequences.isEmpty {
            body["stop"] = params.stopSequences
        }
        if params.seedValue >= 0 {
            body["seed"] = params.seedValue
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
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
