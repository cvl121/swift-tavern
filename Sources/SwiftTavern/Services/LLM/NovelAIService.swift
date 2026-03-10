import Foundation

/// NovelAI text generation API service
/// Endpoint: https://text.novelai.net/ai/generate-stream (streaming) and /ai/generate (non-streaming)
final class NovelAIService: LLMService {
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

                    // NovelAI streams SSE with "data:" prefixed JSON containing { "token": "text" }
                    for try await line in bytes.lines {
                        if let event = SSEParser.parseLine(line) {
                            switch event.type {
                            case .done:
                                continuation.finish()
                                return
                            case .data:
                                if let text = extractStreamToken(from: event.data) {
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
              let output = json["output"] as? String else {
            throw LLMError.noContent
        }

        return output
    }

    // MARK: - Private

    private func buildRequest(messages: [LLMMessage], config: APIConfiguration, stream: Bool) throws -> URLRequest {
        let endpoint = stream ? "/ai/generate-stream" : "/ai/generate"
        guard let url = URL(string: "\(config.effectiveBaseURL)\(endpoint)") else {
            throw LLMError.invalidURL(config.effectiveBaseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        // Build the prompt from messages (NovelAI uses a single prompt string, not chat format)
        let prompt = buildPrompt(from: messages)
        let params = config.generationParams

        var parameters: [String: Any] = [
            "temperature": params.temperature,
            "max_length": params.maxTokens,
            "top_p": params.topP,
        ]

        if params.topK > 0 {
            parameters["top_k"] = params.topK
        }
        if params.repetitionPenalty > 0 {
            parameters["repetition_penalty"] = params.repetitionPenalty
        }
        if params.frequencyPenalty > 0 {
            parameters["frequency_penalty"] = params.frequencyPenalty
        }
        if params.presencePenalty > 0 {
            parameters["presence_penalty"] = params.presencePenalty
        }
        if !params.stopSequences.isEmpty {
            parameters["stop_sequences"] = params.stopSequences.map { Array($0.utf8).map { Int($0) } }
        }

        let body: [String: Any] = [
            "input": prompt,
            "model": config.model,
            "parameters": parameters,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Convert chat messages into a single prompt string for NovelAI's completion-style API
    private func buildPrompt(from messages: [LLMMessage]) -> String {
        var parts: [String] = []
        for message in messages {
            switch message.role {
            case .system:
                parts.append("[ \(message.content) ]")
            case .user:
                parts.append(message.content)
            case .assistant:
                parts.append(message.content)
            }
        }
        // Add a trailing newline to prompt the model to continue
        return parts.joined(separator: "\n") + "\n"
    }

    /// Extract token text from NovelAI's streaming response JSON
    private func extractStreamToken(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else {
            return nil
        }
        return token
    }
}
