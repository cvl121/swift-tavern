import Foundation

/// A group chat definition with multiple characters
struct CharacterGroup: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var members: [String]  // character filenames
    var chatId: String?
    var chats: [String]
    var favorites: [String]
    var disabledMembers: [String]
    var activationStrategy: GroupActivationStrategy

    enum CodingKeys: String, CodingKey {
        case id, name, members, chats, favorites
        case chatId = "chat_id"
        case disabledMembers = "disabled_members"
        case activationStrategy = "activation_strategy"
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        members: [String] = [],
        chatId: String? = nil,
        chats: [String] = [],
        favorites: [String] = [],
        disabledMembers: [String] = [],
        activationStrategy: GroupActivationStrategy = .natural
    ) {
        self.id = id
        self.name = name
        self.members = members
        self.chatId = chatId
        self.chats = chats
        self.favorites = favorites
        self.disabledMembers = disabledMembers
        self.activationStrategy = activationStrategy
    }
}

enum GroupActivationStrategy: String, Codable, CaseIterable {
    case natural = "natural"
    case roundRobin = "round_robin"
    case random = "random"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .natural: return "Natural Order"
        case .roundRobin: return "Round Robin"
        case .random: return "Random"
        case .manual: return "Manual"
        }
    }
}
