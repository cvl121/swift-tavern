import Foundation

/// Ollama local model API service (OpenAI-compatible)
final class OllamaService: LLMService {
    private let openAIService: OpenAIService

    init(session: URLSession = .shared) {
        self.openAIService = OpenAIService(session: session)
    }

    func sendMessage(
        messages: [LLMMessage],
        config: APIConfiguration
    ) -> AsyncThrowingStream<String, Error> {
        // Ollama uses OpenAI-compatible API at /v1/chat/completions
        let adjustedConfig = APIConfiguration(
            apiType: config.apiType,
            apiKey: config.apiKey.isEmpty ? "ollama" : config.apiKey,
            baseURL: (config.baseURL ?? "http://localhost:11434") + "/v1",
            model: config.model,
            generationParams: config.generationParams
        )
        return openAIService.sendMessage(messages: messages, config: adjustedConfig)
    }
}
