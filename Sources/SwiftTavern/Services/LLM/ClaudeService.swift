import Foundation

/// Anthropic Claude Messages API service
final class ClaudeService: LLMService {
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
                            case .event(let name):
                                if name == "message_stop" {
                                    continuation.finish()
                                    return
                                }
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

    // MARK: - Private

    private func buildRequest(messages: [LLMMessage], config: APIConfiguration, stream: Bool) throws -> URLRequest {
        guard let url = URL(string: "\(config.effectiveBaseURL)/v1/messages") else {
            throw LLMError.invalidURL(config.effectiveBaseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Separate system messages from conversation messages.
        // The first system message is the main prompt. System messages that appear
        // AFTER conversation messages (e.g. reminder prompts, post-history instructions)
        // are appended to the system prompt so they stay in context for Claude's API
        // which only supports a single top-level system field.
        var systemPrompt: String?
        var conversationMessages: [[String: String]] = []
        var lateSystemMessages: [String] = []
        var hasSeenConversation = false

        for msg in messages {
            if msg.role == .system {
                if hasSeenConversation {
                    // System message after conversation — keep separate for appending later
                    lateSystemMessages.append(msg.content)
                } else {
                    systemPrompt = (systemPrompt ?? "") + msg.content + "\n"
                }
            } else {
                hasSeenConversation = true
                conversationMessages.append([
                    "role": msg.role.rawValue,
                    "content": msg.content,
                ])
            }
        }

        // Append late system messages (reminders, post-history instructions) to the
        // system prompt with clear labeling so they reinforce at the end of context
        if !lateSystemMessages.isEmpty {
            let lateContent = lateSystemMessages.joined(separator: "\n\n")
            systemPrompt = (systemPrompt ?? "") + "\n\n---\n\n" + lateContent
        }

        // Ensure messages alternate user/assistant and start with user
        var cleanedMessages = ensureAlternatingRoles(conversationMessages)
        if cleanedMessages.isEmpty {
            cleanedMessages = [["role": "user", "content": "Hello"]]
        }

        let params = config.generationParams
        var body: [String: Any] = [
            "model": config.model,
            "messages": cleanedMessages,
            "max_tokens": params.maxTokens,
            "temperature": params.temperature,
            "top_p": params.topP,
            "stream": stream,
        ]

        if let sys = systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !sys.isEmpty {
            body["system"] = sys
        }

        if params.topK > 0 {
            body["top_k"] = params.topK
        }

        if !params.stopSequences.isEmpty {
            body["stop_sequences"] = params.stopSequences
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func ensureAlternatingRoles(_ messages: [[String: String]]) -> [[String: String]] {
        guard !messages.isEmpty else { return messages }

        var result: [[String: String]] = []
        for msg in messages {
            if let lastRole = result.last?["role"], lastRole == msg["role"] {
                // Merge consecutive same-role messages
                if var last = result.last, let existingContent = last["content"], let newContent = msg["content"] {
                    last["content"] = existingContent + "\n" + newContent
                    result[result.count - 1] = last
                }
            } else {
                result.append(msg)
            }
        }

        // Must start with user
        if result.first?["role"] == "assistant" {
            result.insert(["role": "user", "content": "[Start]"], at: 0)
        }

        return result
    }

    private func extractContent(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Claude's streaming format: content_block_delta events have delta.text
        if let delta = json["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            return text
        }

        return nil
    }
}
