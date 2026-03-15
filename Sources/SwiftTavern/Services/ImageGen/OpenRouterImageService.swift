import Foundation

/// OpenRouter image generation service
/// Uses chat completions endpoint with image-capable models.
/// Image models return images in choices[0].message.images array
/// as data URIs (data:image/png;base64,...).
struct OpenRouterImageService: ImageGenerationService {
    func generateImage(
        prompt: String,
        negativePrompt: String? = nil,
        settings: ImageGenerationSettings,
        apiKey: String,
        referenceImage: Data? = nil
    ) async throws -> Data {
        let baseURL = settings.baseURL ?? "https://openrouter.ai/api"
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw ImageGenError.invalidURL(baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("SwiftTavern", forHTTPHeaderField: "X-Title")
        request.timeoutInterval = 120

        // Build message content - multimodal if reference image provided
        let messageContent: Any
        if let referenceImage {
            let base64 = referenceImage.base64EncodedString()
            let dataURI = "data:image/png;base64,\(base64)"
            messageContent = [
                ["type": "image_url", "image_url": ["url": dataURI]],
                ["type": "text", "text": "Using the attached image as a visual reference for the character's appearance, generate a new image based on this prompt: \(prompt)"],
            ] as [[String: Any]]
        } else {
            messageContent = prompt
        }

        let body: [String: Any] = [
            "model": settings.model,
            "messages": [
                ["role": "user", "content": messageContent]
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenError.invalidResponse(statusCode: 0, body: "Not an HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImageGenError.invalidResponse(statusCode: httpResponse.statusCode, body: body)
        }

        // Parse: choices[0].message.images[0].image_url.url = "data:image/png;base64,..."
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let images = message["images"] as? [[String: Any]],
              let firstImage = images.first,
              let imageURL = firstImage["image_url"] as? [String: Any],
              let dataURI = imageURL["url"] as? String else {
            throw ImageGenError.noImageData
        }

        // Extract base64 from data URI: "data:image/png;base64,<base64data>"
        guard let commaIndex = dataURI.firstIndex(of: ",") else {
            throw ImageGenError.noImageData
        }

        let base64String = String(dataURI[dataURI.index(after: commaIndex)...])
        guard let imageData = Data(base64Encoded: base64String) else {
            throw ImageGenError.noImageData
        }

        return imageData
    }
}
