import Foundation

/// Parameters controlling LLM text generation
struct GenerationParameters: Codable, Equatable {
    var maxTokens: Int
    var temperature: Double
    var topP: Double
    var topK: Int
    var frequencyPenalty: Double
    var presencePenalty: Double
    var repetitionPenalty: Double
    var stopSequences: [String]
    var streamResponse: Bool

    enum CodingKeys: String, CodingKey {
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
        case repetitionPenalty = "repetition_penalty"
        case stopSequences = "stop_sequences"
        case streamResponse = "stream_response"
    }

    /// Default preset matching SillyTavern's "Default" preset
    static let `default` = GenerationParameters(
        maxTokens: 2048,
        temperature: 0.7,
        topP: 1.0,
        topK: 0,
        frequencyPenalty: 0.0,
        presencePenalty: 0.0,
        repetitionPenalty: 1.0,
        stopSequences: [],
        streamResponse: true
    )
}
