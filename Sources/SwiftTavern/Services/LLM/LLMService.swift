import Foundation

/// Message role for LLM API calls
enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

/// A message in the LLM conversation format
struct LLMMessage {
    let role: MessageRole
    let content: String
}

/// Protocol for LLM API backends
protocol LLMService {
    /// Send messages and receive a streaming response
    func sendMessage(
        messages: [LLMMessage],
        config: APIConfiguration
    ) -> AsyncThrowingStream<String, Error>

    /// Send messages and receive a complete (non-streaming) response
    func sendMessageComplete(
        messages: [LLMMessage],
        config: APIConfiguration
    ) async throws -> String
}

extension LLMService {
    /// Default implementation: collect streaming chunks
    func sendMessageComplete(
        messages: [LLMMessage],
        config: APIConfiguration
    ) async throws -> String {
        var result = ""
        for try await chunk in sendMessage(messages: messages, config: config) {
            result += chunk
        }
        return result
    }
}

enum LLMError: Error, LocalizedError {
    case invalidURL(String = "")
    case invalidResponse(statusCode: Int, body: String)
    case streamingError(String)
    case noContent
    case apiKeyMissing

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return url.isEmpty ? "Invalid API URL" : "Invalid API URL: \(url)"
        case .invalidResponse(let code, let body): return "API error (\(code)): \(body.truncated(to: 200))"
        case .streamingError(let msg): return "Streaming error: \(msg)"
        case .noContent: return "No content in response"
        case .apiKeyMissing: return "API key is not configured"
        }
    }
}
