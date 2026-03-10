import Foundation

/// A standalone World Info book (stored as JSON in worlds/ directory)
struct WorldInfo: Codable, Identifiable, Equatable {
    var id: String { name }
    var name: String
    var entries: [String: WorldInfoEntry]

    init(name: String, entries: [String: WorldInfoEntry] = [:]) {
        self.name = name
        self.entries = entries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // SillyTavern world info files don't have a "name" field;
        // the name is derived from the filename by WorldInfoStorageService.
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        entries = try container.decodeIfPresent([String: WorldInfoEntry].self, forKey: .entries) ?? [:]
    }

    enum CodingKeys: String, CodingKey {
        case name, entries
    }
}

struct WorldInfoEntry: Codable, Identifiable, Equatable {
    var id: Int { uid }

    var uid: Int
    var keys: [String]
    var content: String
    var enabled: Bool
    var insertionOrder: Int
    var caseSensitive: Bool
    var selective: Bool
    var secondaryKeys: [String]
    var constant: Bool
    var position: EntryPosition
    var comment: String

    enum CodingKeys: String, CodingKey {
        case uid, keys, content, enabled, selective, constant, position, comment
        case insertionOrder = "insertion_order"
        case caseSensitive = "case_sensitive"
        case secondaryKeys = "secondary_keys"
        // SillyTavern alternate field names
        case key, keysecondary, order, disable
    }

    init(
        uid: Int,
        keys: [String] = [],
        content: String = "",
        enabled: Bool = false,
        insertionOrder: Int = 100,
        caseSensitive: Bool = false,
        selective: Bool = false,
        secondaryKeys: [String] = [],
        constant: Bool = false,
        position: EntryPosition = .beforeChar,
        comment: String = ""
    ) {
        self.uid = uid
        self.keys = keys
        self.content = content
        self.enabled = enabled
        self.insertionOrder = insertionOrder
        self.caseSensitive = caseSensitive
        self.selective = selective
        self.secondaryKeys = secondaryKeys
        self.constant = constant
        self.position = position
        self.comment = comment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(Int.self, forKey: .uid)
        let rawContent = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        let rawComment = try container.decodeIfPresent(String.self, forKey: .comment) ?? ""
        // SillyTavern stores lore text in "comment" with "content" empty;
        // SwiftTavern uses "content" as the primary field for prompt injection.
        // Normalize: if content is empty but comment has text, use comment as content.
        if rawContent.isEmpty && !rawComment.isEmpty {
            content = rawComment
            comment = rawComment
        } else {
            content = rawContent
            comment = rawComment
        }
        selective = try container.decodeIfPresent(Bool.self, forKey: .selective) ?? false
        constant = try container.decodeIfPresent(Bool.self, forKey: .constant) ?? false

        // Handle "keys" (SwiftTavern) or "key" (SillyTavern)
        if let k = try? container.decode([String].self, forKey: .keys) {
            keys = k
        } else if let k = try? container.decode([String].self, forKey: .key) {
            keys = k
        } else {
            keys = []
        }

        // Handle "secondary_keys" (SwiftTavern) or "keysecondary" (SillyTavern)
        if let sk = try? container.decode([String].self, forKey: .secondaryKeys) {
            secondaryKeys = sk
        } else if let sk = try? container.decode([String].self, forKey: .keysecondary) {
            secondaryKeys = sk
        } else {
            secondaryKeys = []
        }

        // Handle "insertion_order" (SwiftTavern) or "order" (SillyTavern)
        if let o = try? container.decode(Int.self, forKey: .insertionOrder) {
            insertionOrder = o
        } else if let o = try? container.decode(Int.self, forKey: .order) {
            insertionOrder = o
        } else {
            insertionOrder = 100
        }

        // Handle "enabled" (SwiftTavern) or invert "disable" (SillyTavern)
        if let e = try? container.decode(Bool.self, forKey: .enabled) {
            enabled = e
        } else if let d = try? container.decode(Bool.self, forKey: .disable) {
            enabled = !d
        } else {
            enabled = true
        }

        // Handle nullable caseSensitive (SillyTavern sends null)
        caseSensitive = (try? container.decodeIfPresent(Bool.self, forKey: .caseSensitive)) ?? false

        // Handle position (integer or string)
        if container.contains(.position) {
            position = (try? container.decode(EntryPosition.self, forKey: .position)) ?? .beforeChar
        } else {
            position = .beforeChar
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uid, forKey: .uid)
        try container.encode(keys, forKey: .keys)
        try container.encode(content, forKey: .content)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(insertionOrder, forKey: .insertionOrder)
        try container.encode(caseSensitive, forKey: .caseSensitive)
        try container.encode(selective, forKey: .selective)
        try container.encode(secondaryKeys, forKey: .secondaryKeys)
        try container.encode(constant, forKey: .constant)
        try container.encode(position, forKey: .position)
        try container.encode(comment, forKey: .comment)
    }
}
