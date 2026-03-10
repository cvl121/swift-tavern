import Foundation

/// A single chat message in a conversation
struct ChatMessage: Codable, Identifiable, Equatable {
    /// Stable unique identifier for each message instance
    let messageId: String
    var id: String { messageId }

    var name: String
    var isUser: Bool
    var isSystem: Bool
    var sendDate: String
    var mes: String
    var extra: [String: AnyCodable]?
    var swipeId: Int?
    var swipes: [String]?
    var isBookmarked: Bool

    enum CodingKeys: String, CodingKey {
        case name, mes, extra, swipes
        case messageId = "message_id"
        case isUser = "is_user"
        case isSystem = "is_system"
        case sendDate = "send_date"
        case swipeId = "swipe_id"
        case isBookmarked = "is_bookmarked"
    }

    init(
        name: String,
        isUser: Bool,
        isSystem: Bool = false,
        sendDate: String = "",
        mes: String,
        extra: [String: AnyCodable]? = nil,
        isBookmarked: Bool = false
    ) {
        self.messageId = UUID().uuidString
        self.name = name
        self.isUser = isUser
        self.isSystem = isSystem
        self.sendDate = sendDate.isEmpty ? ChatMessage.currentDateString() : sendDate
        self.mes = mes
        self.extra = extra
        self.isBookmarked = isBookmarked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Generate a new UUID if not present in stored data (backwards compatible)
        messageId = try container.decodeIfPresent(String.self, forKey: .messageId) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        isSystem = try container.decodeIfPresent(Bool.self, forKey: .isSystem) ?? false
        sendDate = try container.decode(String.self, forKey: .sendDate)
        mes = try container.decode(String.self, forKey: .mes)
        extra = try container.decodeIfPresent([String: AnyCodable].self, forKey: .extra)
        swipeId = try container.decodeIfPresent(Int.self, forKey: .swipeId)
        swipes = try container.decodeIfPresent([String].self, forKey: .swipes)
        isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
    }

    static func currentDateString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}

/// Chat metadata - first line of a JSONL chat file
struct ChatMetadata: Codable, Equatable {
    var userName: String
    var characterName: String
    var chatMetadata: ChatMetadataInfo
    var createDate: String?

    enum CodingKeys: String, CodingKey {
        case userName = "user_name"
        case characterName = "character_name"
        case chatMetadata = "chat_metadata"
        case createDate = "create_date"
    }
}

struct ChatMetadataInfo: Codable, Equatable {
    var note: String?
    var tpiDescription: String?

    enum CodingKeys: String, CodingKey {
        case note
        case tpiDescription = "tpi_description"
    }

    init(note: String? = nil, tpiDescription: String? = nil) {
        self.note = note
        self.tpiDescription = tpiDescription
    }
}

/// Represents a complete chat session with metadata and messages
struct ChatSession: Identifiable, Equatable {
    let id: String
    let filename: String
    var metadata: ChatMetadata
    var messages: [ChatMessage]

    var lastMessage: String {
        messages.last?.mes ?? ""
    }

    var lastMessageDate: String {
        messages.last?.sendDate ?? metadata.createDate ?? ""
    }

    var messageCount: Int {
        messages.count
    }
}
