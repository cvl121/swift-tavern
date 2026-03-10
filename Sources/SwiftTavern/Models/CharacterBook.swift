import Foundation

/// World Info / Character Book - context injection based on keywords
struct CharacterBook: Codable, Equatable {
    var name: String?
    var description: String?
    var scanDepth: Int?
    var tokenBudget: Int?
    var recursiveScanning: Bool?
    var extensions: [String: AnyCodable]?
    var entries: [CharacterBookEntry]

    enum CodingKeys: String, CodingKey {
        case name, description, extensions, entries
        case scanDepth = "scan_depth"
        case tokenBudget = "token_budget"
        case recursiveScanning = "recursive_scanning"
    }
}

struct CharacterBookEntry: Codable, Equatable, Identifiable {
    var id: Int { uid }

    var uid: Int
    var keys: [String]
    var content: String
    var enabled: Bool
    var insertionOrder: Int
    var caseSensitive: Bool?
    var name: String?
    var priority: Int?
    var comment: String?
    var selective: Bool
    var secondaryKeys: [String]?
    var constant: Bool
    var position: EntryPosition?
    var extensions: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case uid, keys, content, enabled, name, priority, comment, selective, constant, position, extensions
        case insertionOrder = "insertion_order"
        case caseSensitive = "case_sensitive"
        case secondaryKeys = "secondary_keys"
    }
}

enum EntryPosition: String, Codable, Equatable, CaseIterable {
    case beforeChar = "before_char"
    case afterChar = "after_char"
    case beforeExample = "before_example"
    case afterExample = "after_example"
    case atDepth = "at_depth"

    var displayName: String {
        switch self {
        case .beforeChar: return "Before Character"
        case .afterChar: return "After Character"
        case .beforeExample: return "Before Examples"
        case .afterExample: return "After Examples"
        case .atDepth: return "At Depth"
        }
    }

    // Also support integer coding for SillyTavern compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = EntryPosition(rawValue: stringValue) ?? .beforeChar
        } else if let intValue = try? container.decode(Int.self) {
            switch intValue {
            case 0: self = .beforeChar
            case 1: self = .afterChar
            case 2: self = .beforeExample
            case 3: self = .afterExample
            case 4: self = .atDepth
            default: self = .beforeChar
            }
        } else {
            self = .beforeChar
        }
    }
}
