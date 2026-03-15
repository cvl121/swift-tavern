import Foundation

/// Parameters controlling LLM text generation
/// LLM chat completion generation parameters
struct GenerationParameters: Codable, Equatable {
    var maxTokens: Int
    var contextSize: Int
    var temperature: Double
    var topP: Double
    var topK: Int
    var frequencyPenalty: Double
    var presencePenalty: Double
    var repetitionPenalty: Double
    var stopSequences: [String]
    var streamResponse: Bool

    // Advanced sampling parameters
    var minP: Double
    var topA: Double
    var typicalP: Double
    var tfs: Double
    var mirostatMode: Int
    var mirostatTau: Double
    var mirostatEta: Double
    var encoderRepetitionPenalty: Double
    var noRepeatNgramSize: Int
    var minLength: Int
    var smoothingFactor: Double
    var smoothingCurve: Double
    var dynaTempEnabled: Bool
    var dynaTempLow: Double
    var dynaTempHigh: Double
    var dynaTempExponent: Double
    var seedValue: Int

    enum CodingKeys: String, CodingKey {
        case maxTokens = "max_tokens"
        case contextSize = "context_size"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
        case repetitionPenalty = "repetition_penalty"
        case stopSequences = "stop_sequences"
        case streamResponse = "stream_response"
        case minP = "min_p"
        case topA = "top_a"
        case typicalP = "typical_p"
        case tfs
        case mirostatMode = "mirostat_mode"
        case mirostatTau = "mirostat_tau"
        case mirostatEta = "mirostat_eta"
        case encoderRepetitionPenalty = "encoder_repetition_penalty"
        case noRepeatNgramSize = "no_repeat_ngram_size"
        case minLength = "min_length"
        case smoothingFactor = "smoothing_factor"
        case smoothingCurve = "smoothing_curve"
        case dynaTempEnabled = "dynatemp"
        case dynaTempLow = "dynatemp_low"
        case dynaTempHigh = "dynatemp_high"
        case dynaTempExponent = "dynatemp_exponent"
        case seedValue = "seed"
    }

    /// Default generation parameter preset
    static let `default` = GenerationParameters(
        maxTokens: 2048,
        contextSize: 4096,
        temperature: 0.7,
        topP: 1.0,
        topK: 0,
        frequencyPenalty: 0.0,
        presencePenalty: 0.0,
        repetitionPenalty: 1.0,
        stopSequences: [],
        streamResponse: true,
        minP: 0.0,
        topA: 0.0,
        typicalP: 1.0,
        tfs: 1.0,
        mirostatMode: 0,
        mirostatTau: 5.0,
        mirostatEta: 0.1,
        encoderRepetitionPenalty: 1.0,
        noRepeatNgramSize: 0,
        minLength: 0,
        smoothingFactor: 0.0,
        smoothingCurve: 1.0,
        dynaTempEnabled: false,
        dynaTempLow: 0.5,
        dynaTempHigh: 1.5,
        dynaTempExponent: 1.0,
        seedValue: -1
    )

    init(
        maxTokens: Int = 2048,
        contextSize: Int = 4096,
        temperature: Double = 0.7,
        topP: Double = 1.0,
        topK: Int = 0,
        frequencyPenalty: Double = 0.0,
        presencePenalty: Double = 0.0,
        repetitionPenalty: Double = 1.0,
        stopSequences: [String] = [],
        streamResponse: Bool = true,
        minP: Double = 0.0,
        topA: Double = 0.0,
        typicalP: Double = 1.0,
        tfs: Double = 1.0,
        mirostatMode: Int = 0,
        mirostatTau: Double = 5.0,
        mirostatEta: Double = 0.1,
        encoderRepetitionPenalty: Double = 1.0,
        noRepeatNgramSize: Int = 0,
        minLength: Int = 0,
        smoothingFactor: Double = 0.0,
        smoothingCurve: Double = 1.0,
        dynaTempEnabled: Bool = false,
        dynaTempLow: Double = 0.5,
        dynaTempHigh: Double = 1.5,
        dynaTempExponent: Double = 1.0,
        seedValue: Int = -1
    ) {
        self.maxTokens = maxTokens
        self.contextSize = contextSize
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.repetitionPenalty = repetitionPenalty
        self.stopSequences = stopSequences
        self.streamResponse = streamResponse
        self.minP = minP
        self.topA = topA
        self.typicalP = typicalP
        self.tfs = tfs
        self.mirostatMode = mirostatMode
        self.mirostatTau = mirostatTau
        self.mirostatEta = mirostatEta
        self.encoderRepetitionPenalty = encoderRepetitionPenalty
        self.noRepeatNgramSize = noRepeatNgramSize
        self.minLength = minLength
        self.smoothingFactor = smoothingFactor
        self.smoothingCurve = smoothingCurve
        self.dynaTempEnabled = dynaTempEnabled
        self.dynaTempLow = dynaTempLow
        self.dynaTempHigh = dynaTempHigh
        self.dynaTempExponent = dynaTempExponent
        self.seedValue = seedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxTokens = try container.decode(Int.self, forKey: .maxTokens)
        contextSize = try container.decodeIfPresent(Int.self, forKey: .contextSize) ?? 4096
        temperature = try container.decode(Double.self, forKey: .temperature)
        topP = try container.decode(Double.self, forKey: .topP)
        topK = try container.decode(Int.self, forKey: .topK)
        frequencyPenalty = try container.decode(Double.self, forKey: .frequencyPenalty)
        presencePenalty = try container.decode(Double.self, forKey: .presencePenalty)
        repetitionPenalty = try container.decode(Double.self, forKey: .repetitionPenalty)
        stopSequences = try container.decode([String].self, forKey: .stopSequences)
        streamResponse = try container.decode(Bool.self, forKey: .streamResponse)
        minP = try container.decodeIfPresent(Double.self, forKey: .minP) ?? 0.0
        topA = try container.decodeIfPresent(Double.self, forKey: .topA) ?? 0.0
        typicalP = try container.decodeIfPresent(Double.self, forKey: .typicalP) ?? 1.0
        tfs = try container.decodeIfPresent(Double.self, forKey: .tfs) ?? 1.0
        mirostatMode = try container.decodeIfPresent(Int.self, forKey: .mirostatMode) ?? 0
        mirostatTau = try container.decodeIfPresent(Double.self, forKey: .mirostatTau) ?? 5.0
        mirostatEta = try container.decodeIfPresent(Double.self, forKey: .mirostatEta) ?? 0.1
        encoderRepetitionPenalty = try container.decodeIfPresent(Double.self, forKey: .encoderRepetitionPenalty) ?? 1.0
        noRepeatNgramSize = try container.decodeIfPresent(Int.self, forKey: .noRepeatNgramSize) ?? 0
        minLength = try container.decodeIfPresent(Int.self, forKey: .minLength) ?? 0
        smoothingFactor = try container.decodeIfPresent(Double.self, forKey: .smoothingFactor) ?? 0.0
        smoothingCurve = try container.decodeIfPresent(Double.self, forKey: .smoothingCurve) ?? 1.0
        dynaTempEnabled = try container.decodeIfPresent(Bool.self, forKey: .dynaTempEnabled) ?? false
        dynaTempLow = try container.decodeIfPresent(Double.self, forKey: .dynaTempLow) ?? 0.5
        dynaTempHigh = try container.decodeIfPresent(Double.self, forKey: .dynaTempHigh) ?? 1.5
        dynaTempExponent = try container.decodeIfPresent(Double.self, forKey: .dynaTempExponent) ?? 1.0
        seedValue = try container.decodeIfPresent(Int.self, forKey: .seedValue) ?? -1
    }
}
