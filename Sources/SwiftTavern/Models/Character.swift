import Foundation

/// TavernCardV2 specification - character card data format
/// TavernCardV2 character card data format (SillyTavern-compatible)
struct TavernCardV2: Codable, Equatable {
    var spec: String = "chara_card_v2"
    var specVersion: String = "2.0"
    var data: CharacterData

    enum CodingKeys: String, CodingKey {
        case spec
        case specVersion = "spec_version"
        case data
    }
}

struct CharacterData: Codable, Equatable, Identifiable {
    var id: String { name + (characterVersion ?? "") }

    var name: String
    var description: String
    var personality: String
    var scenario: String
    var firstMes: String
    var mesExample: String
    var creatorNotes: String
    var systemPrompt: String
    var postHistoryInstructions: String
    var alternateGreetings: [String]
    var characterBook: CharacterBook?
    var tags: [String]
    var creator: String
    var characterVersion: String?
    var extensions: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case name, description, personality, scenario
        case firstMes = "first_mes"
        case mesExample = "mes_example"
        case creatorNotes = "creator_notes"
        case systemPrompt = "system_prompt"
        case postHistoryInstructions = "post_history_instructions"
        case alternateGreetings = "alternate_greetings"
        case characterBook = "character_book"
        case tags, creator
        case characterVersion = "character_version"
        case extensions
    }

    init(
        name: String = "",
        description: String = "",
        personality: String = "",
        scenario: String = "",
        firstMes: String = "",
        mesExample: String = "",
        creatorNotes: String = "",
        systemPrompt: String = "",
        postHistoryInstructions: String = "",
        alternateGreetings: [String] = [],
        characterBook: CharacterBook? = nil,
        tags: [String] = [],
        creator: String = "",
        characterVersion: String? = nil,
        extensions: [String: AnyCodable]? = nil
    ) {
        self.name = name
        self.description = description
        self.personality = personality
        self.scenario = scenario
        self.firstMes = firstMes
        self.mesExample = mesExample
        self.creatorNotes = creatorNotes
        self.systemPrompt = systemPrompt
        self.postHistoryInstructions = postHistoryInstructions
        self.alternateGreetings = alternateGreetings
        self.characterBook = characterBook
        self.tags = tags
        self.creator = creator
        self.characterVersion = characterVersion
        self.extensions = extensions
    }
}

/// A type-erased Codable value for arbitrary JSON
struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull): return true
        case let (l as Bool, r as Bool): return l == r
        case let (l as Int, r as Int): return l == r
        case let (l as Double, r as Double): return l == r
        case let (l as String, r as String): return l == r
        default: return false
        }
    }
}

/// Represents a loaded character with its avatar image data and filename
struct CharacterEntry: Identifiable {
    let id: String
    let filename: String
    let card: TavernCardV2
    let avatarData: Data?

    init(filename: String, card: TavernCardV2, avatarData: Data?) {
        self.id = filename
        self.filename = filename
        self.card = card
        self.avatarData = avatarData
    }
}
