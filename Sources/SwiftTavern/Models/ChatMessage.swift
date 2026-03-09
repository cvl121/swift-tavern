import Foundation

/// A single chat message in a conversation
struct ChatMessage: Codable, Identifiable, Equatable {
    var id: String { "\(name)-\(sendDate)" }

    var name: String
    var isUser: Bool
    var isSystem: Bool
    var sendDate: String
    var mes: String
    var extra: [String: AnyCodable]?
    var swipeId: Int?
    var swipes: [String]?

    enum CodingKeys: String, CodingKey {
        case name, mes, extra, swipes
        case isUser = "is_user"
        case isSystem = "is_system"
        case sendDate = "send_date"
        case swipeId = "swipe_id"
    }

    init(
        name: String,
        isUser: Bool,
        isSystem: Bool = false,
        sendDate: String = "",
        mes: String,
        extra: [String: AnyCodable]? = nil
    ) {
        self.name = name
        self.isUser = isUser
        self.isSystem = isSystem
        self.sendDate = sendDate.isEmpty ? ChatMessage.currentDateString() : sendDate
        self.mes = mes
        self.extra = extra
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
