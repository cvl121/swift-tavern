import Foundation

/// Factory for creating the appropriate LLM service for a given API type
enum LLMServiceFactory {
    static func create(for apiType: APIType) -> LLMService {
        switch apiType {
        case .openai:
            return OpenAIService()
        case .claude:
            return ClaudeService()
        case .gemini:
            return GeminiService()
        case .ollama:
            return OllamaService()
        case .openrouter:
            return OpenRouterService()
        case .novelai:
            return NovelAIService()
        }
    }
}
