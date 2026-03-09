import Foundation

/// Full API configuration including the resolved API key
struct APIConfiguration {
    let apiType: APIType
    let apiKey: String
    let baseURL: String?
    let model: String
    let generationParams: GenerationParameters

    var effectiveBaseURL: String {
        if let base = baseURL, !base.isEmpty {
            return base
        }
        switch apiType {
        case .openai:
            return "https://api.openai.com/v1"
        case .claude:
            return "https://api.anthropic.com"
        case .gemini:
            return "https://generativelanguage.googleapis.com"
        case .ollama:
            return "http://localhost:11434"
        case .openrouter:
            return "https://openrouter.ai/api/v1"
        }
    }
}
