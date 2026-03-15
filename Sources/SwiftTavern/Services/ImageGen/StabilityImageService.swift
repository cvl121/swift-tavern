import Foundation

/// Stability AI image generation service
struct StabilityImageService: ImageGenerationService {
    func generateImage(
        prompt: String,
        negativePrompt: String? = nil,
        settings: ImageGenerationSettings,
        apiKey: String,
        referenceImage: Data? = nil
    ) async throws -> Data {
        let baseURL = settings.baseURL ?? "https://api.stability.ai"
        let model = settings.model.isEmpty ? "stable-diffusion-xl-1024-v1-0" : settings.model
        guard let url = URL(string: "\(baseURL)/v1/generation/\(model)/text-to-image") else {
            throw ImageGenError.invalidURL(baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        var textPrompts: [[String: Any]] = [
            ["text": prompt, "weight": 1.0]
        ]
        if let neg = negativePrompt, !neg.isEmpty {
            textPrompts.append(["text": neg, "weight": -1.0])
        }

        let body: [String: Any] = [
            "text_prompts": textPrompts,
            "cfg_scale": 7,
            "height": settings.imageSize.height,
            "width": settings.imageSize.width,
            "samples": 1,
            "steps": 30,
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
              let artifacts = json["artifacts"] as? [[String: Any]],
              let first = artifacts.first,
              let b64String = first["base64"] as? String,
              let imageData = Data(base64Encoded: b64String) else {
            throw ImageGenError.noImageData
        }

        return imageData
    }
}
