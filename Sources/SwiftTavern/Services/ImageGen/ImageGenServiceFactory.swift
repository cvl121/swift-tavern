import Foundation

/// Factory for creating image generation service implementations
enum ImageGenServiceFactory {
    static func create(for provider: ImageGenProvider) -> ImageGenerationService {
        switch provider {
        case .openaiDalle:
            return DalleImageService()
        case .stabilityAI:
            return StabilityImageService()
        case .openrouter:
            return OpenRouterImageService()
        case .novelai:
            return NovelAIImageService()
        case .custom:
            // Custom provider uses DALL-E compatible format
            return DalleImageService()
        }
    }
}
