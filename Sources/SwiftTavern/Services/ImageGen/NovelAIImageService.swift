import Foundation
import Compression

/// NovelAI image generation service
/// Uses the NovelAI Diffusion API at https://image.novelai.net/ai/generate-image
struct NovelAIImageService: ImageGenerationService {
    func generateImage(
        prompt: String,
        settings: ImageGenerationSettings,
        apiKey: String
    ) async throws -> Data {
        let baseURL = settings.baseURL ?? "https://image.novelai.net"
        guard let url = URL(string: "\(baseURL)/ai/generate-image") else {
            throw ImageGenError.invalidURL(baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let model = settings.model.isEmpty ? "nai-diffusion-3" : settings.model
        let isV4 = model.contains("diffusion-4")

        let body = buildRequestBody(
            prompt: prompt,
            model: model,
            isV4: isV4,
            settings: settings
        )

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenError.invalidResponse(statusCode: 0, body: "Not an HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImageGenError.invalidResponse(statusCode: httpResponse.statusCode, body: body)
        }

        // NovelAI returns a zip file containing the image
        if let imageData = extractImageFromZip(data) {
            return imageData
        }

        // Fallback: try parsing as JSON with base64
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let b64String = json["data"] as? String,
           let imageData = Data(base64Encoded: b64String) {
            return imageData
        }

        // Last fallback: maybe the response IS the raw image data (PNG)
        if data.count > 8 && data.isPNG {
            return data
        }

        throw ImageGenError.noImageData
    }

    // MARK: - Request Body

    /// Build the request body, using v4 prompt format for v4+ models
    private func buildRequestBody(
        prompt: String,
        model: String,
        isV4: Bool,
        settings: ImageGenerationSettings
    ) -> [String: Any] {
        let negativePrompt = "lowres, bad anatomy, bad hands, text, error, missing fingers, extra digit, fewer digits, cropped, worst quality, low quality, normal quality, jpeg artifacts, signature, watermark, username, blurry"
        let seed = Int.random(in: 0...Int(Int32.max))

        var parameters: [String: Any] = [
            "width": settings.imageSize.width,
            "height": settings.imageSize.height,
            "n_samples": 1,
            "seed": seed,
            "negative_prompt": negativePrompt,
        ]

        if isV4 {
            // V4+ models require v4_prompt format and different parameters
            parameters["scale"] = 6.0
            parameters["sampler"] = "k_euler_ancestral"
            parameters["steps"] = 23
            parameters["ucPreset"] = 3
            parameters["qualityToggle"] = settings.quality == .hd
            parameters["sm"] = false
            parameters["sm_dyn"] = false
            parameters["cfg_rescale"] = 0
            parameters["noise_schedule"] = "native"
            parameters["legacy"] = false
            parameters["params_version"] = 3
            parameters["use_coords"] = false
            parameters["v4_prompt"] = [
                "caption": [
                    "base_caption": prompt,
                    "char_captions": [] as [[String: Any]],
                ],
                "use_coords": false,
                "use_order": false,
            ] as [String: Any]
            parameters["v4_negative_prompt"] = [
                "caption": [
                    "base_caption": negativePrompt,
                    "char_captions": [] as [[String: Any]],
                ],
                "use_coords": false,
                "use_order": false,
            ] as [String: Any]
        } else {
            // V3 and older models use simpler parameters
            parameters["scale"] = 5.0
            parameters["sampler"] = "k_euler"
            parameters["steps"] = 28
            parameters["ucPreset"] = 0
            parameters["qualityToggle"] = settings.quality == .hd
        }

        return [
            "input": prompt,
            "model": model,
            "action": "generate",
            "parameters": parameters,
        ]
    }

    // MARK: - Zip Extraction

    /// Extract a PNG image from a zip archive (NovelAI returns images in zip format)
    /// Handles both stored (method 0) and deflated (method 8) entries.
    private func extractImageFromZip(_ zipData: Data) -> Data? {
        let bytes = Array(zipData)
        guard bytes.count > 30 else { return nil }

        // Verify PK signature
        guard bytes[0] == 0x50 && bytes[1] == 0x4B &&
              bytes[2] == 0x03 && bytes[3] == 0x04 else {
            return nil
        }

        let compressionMethod = UInt16(bytes[8]) | UInt16(bytes[9]) << 8
        let compressedSize = Int(UInt32(bytes[18]) | UInt32(bytes[19]) << 8 |
                                 UInt32(bytes[20]) << 16 | UInt32(bytes[21]) << 24)
        let uncompressedSize = Int(UInt32(bytes[22]) | UInt32(bytes[23]) << 8 |
                                   UInt32(bytes[24]) << 16 | UInt32(bytes[25]) << 24)
        let filenameLen = Int(UInt16(bytes[26]) | UInt16(bytes[27]) << 8)
        let extraLen = Int(UInt16(bytes[28]) | UInt16(bytes[29]) << 8)

        let dataOffset = 30 + filenameLen + extraLen
        let dataEnd = dataOffset + compressedSize

        guard dataEnd <= bytes.count else { return nil }

        let compressedData = Data(bytes[dataOffset..<dataEnd])

        let fileData: Data
        if compressionMethod == 0 {
            // Stored (no compression)
            fileData = compressedData
        } else if compressionMethod == 8 {
            // Deflate — decompress using Apple's Compression framework
            guard let decompressed = decompressDeflate(compressedData, expectedSize: uncompressedSize) else {
                return nil
            }
            fileData = decompressed
        } else {
            return nil
        }

        // Verify it's a PNG
        if fileData.count >= 8 && fileData.isPNG {
            return fileData
        }

        return nil
    }

    /// Decompress raw deflate data using the Compression framework
    private func decompressDeflate(_ data: Data, expectedSize: Int) -> Data? {
        // Allocate buffer with some headroom
        let bufferSize = max(expectedSize, data.count * 4)
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }

        let decompressedSize = data.withUnsafeBytes { srcBuffer -> Int in
            guard let srcPointer = srcBuffer.baseAddress?.bindMemory(to: UInt8.self, capacity: data.count) else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer, bufferSize,
                srcPointer, data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decompressedSize > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
}
