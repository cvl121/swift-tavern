import Foundation

/// A named generation parameter preset, compatible with SillyTavern preset format
struct ChatPreset: Codable, Identifiable, Equatable {
    var id: String { name }

    var name: String
    var generationParams: GenerationParameters

    enum CodingKeys: String, CodingKey {
        case name
        case generationParams = "generation_params"
    }

    static let `default` = ChatPreset(
        name: "Default",
        generationParams: .default
    )
}
