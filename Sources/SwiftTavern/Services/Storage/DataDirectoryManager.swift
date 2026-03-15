import Foundation

/// Manages the application data directory structure
final class DataDirectoryManager {
    let rootDirectory: URL

    /// Standard subdirectory names
    static let subdirectories = [
        "characters",
        "chats",
        "groups",
        "group chats",
        "worlds",
        "presets",
        "user",
        "User Avatars",
        "backgrounds",
        "themes",
        "backups",
        "thumbnails",
        "generated_images",
    ]

    init(rootDirectory: URL? = nil) {
        self.rootDirectory = rootDirectory ?? FileManager.appSupportDirectory
    }

    /// Create all required directories if they don't exist
    func ensureDirectoriesExist() throws {
        let fm = FileManager.default
        for subdir in DataDirectoryManager.subdirectories {
            let dirURL = rootDirectory.appendingPathComponent(subdir, isDirectory: true)
            if !fm.fileExists(atPath: dirURL.path) {
                try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
            }
        }
    }

    func url(for subdirectory: String) -> URL {
        rootDirectory.appendingPathComponent(subdirectory, isDirectory: true)
    }

    var charactersDirectory: URL { url(for: "characters") }
    var chatsDirectory: URL { url(for: "chats") }
    var groupsDirectory: URL { url(for: "groups") }
    var groupChatsDirectory: URL { url(for: "group chats") }
    var worldsDirectory: URL { url(for: "worlds") }
    var userDirectory: URL { url(for: "user") }
    var userAvatarsDirectory: URL { url(for: "User Avatars") }
    var backgroundsDirectory: URL { url(for: "backgrounds") }
    var presetsDirectory: URL { url(for: "presets") }
    var backupsDirectory: URL { url(for: "backups") }
    var generatedImagesDirectory: URL { url(for: "generated_images") }

    var settingsFile: URL {
        userDirectory.appendingPathComponent("settings.json")
    }
}
