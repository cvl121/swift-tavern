import Foundation

/// User persona - represents the user's character/identity in conversations
struct Persona: Codable, Identifiable, Equatable {
    var id: String { name }

    var name: String
    var description: String
    var avatarFilename: String?

    init(name: String, description: String = "", avatarFilename: String? = nil) {
        self.name = name
        self.description = description
        self.avatarFilename = avatarFilename
    }
}
