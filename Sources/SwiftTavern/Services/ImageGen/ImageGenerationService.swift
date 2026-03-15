import Foundation

/// Errors that can occur during image generation
enum ImageGenError: Error, LocalizedError {
    case invalidURL(String)
    case apiKeyMissing
    case invalidResponse(statusCode: Int, body: String)
    case noImageData
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid image API URL: \(url)"
        case .apiKeyMissing: return "Image generation API key is not configured"
        case .invalidResponse(let code, let body): return "Image API error (\(code)): \(body.truncated(to: 200))"
        case .noImageData: return "No image data in response"
        case .saveFailed(let reason): return "Failed to save image: \(reason)"
        }
    }
}

/// Protocol for image generation backends
protocol ImageGenerationService {
    /// Generate an image from a text prompt
    /// - Returns: PNG image data
    func generateImage(
        prompt: String,
        negativePrompt: String?,
        settings: ImageGenerationSettings,
        apiKey: String,
        referenceImage: Data?
    ) async throws -> Data
}

extension ImageGenerationService {
    /// Convenience overload without negative prompt or reference image
    func generateImage(
        prompt: String,
        settings: ImageGenerationSettings,
        apiKey: String
    ) async throws -> Data {
        try await generateImage(prompt: prompt, negativePrompt: nil, settings: settings, apiKey: apiKey, referenceImage: nil)
    }

    /// Convenience overload without reference image
    func generateImage(
        prompt: String,
        negativePrompt: String?,
        settings: ImageGenerationSettings,
        apiKey: String
    ) async throws -> Data {
        try await generateImage(prompt: prompt, negativePrompt: negativePrompt, settings: settings, apiKey: apiKey, referenceImage: nil)
    }
}
