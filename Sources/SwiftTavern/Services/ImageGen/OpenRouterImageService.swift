import Foundation

/// OpenRouter image generation service (uses OpenAI-compatible format)
struct OpenRouterImageService: ImageGenerationService {
    func generateImage(
        prompt: String,
        settings: ImageGenerationSettings,
        apiKey: String
    ) async throws -> Data {
        let baseURL = settings.baseURL ?? "https://openrouter.ai/api"
        guard let url = URL(string: "\(baseURL)/v1/images/generations") else {
            throw ImageGenError.invalidURL(baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("SwiftTavern", forHTTPHeaderField: "X-Title")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": settings.model,
            "prompt": prompt,
            "n": 1,
            "response_format": "b64_json",
            "size": settings.imageSize.rawValue,
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

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first,
              let b64String = first["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64String) else {
            throw ImageGenError.noImageData
        }

        return imageData
    }
}
