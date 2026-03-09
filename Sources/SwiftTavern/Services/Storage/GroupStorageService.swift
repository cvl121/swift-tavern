import Foundation

/// Service for managing group definitions
final class GroupStorageService {
    private let directoryManager: DataDirectoryManager

    init(directoryManager: DataDirectoryManager) {
        self.directoryManager = directoryManager
    }

    /// Load all groups
    func loadAll() throws -> [CharacterGroup] {
        let dir = directoryManager.groupsDirectory
        let fm = FileManager.default

        guard fm.fileExists(atPath: dir.path) else { return [] }

        let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }

        return files.compactMap { url in
            try? loadGroup(from: url)
        }
    }

    /// Load a single group
    func loadGroup(from fileURL: URL) throws -> CharacterGroup {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(CharacterGroup.self, from: data)
    }

    /// Save a group
    func save(_ group: CharacterGroup) throws {
        let filename = "\(group.id).json"
        let fileURL = directoryManager.groupsDirectory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(group)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Delete a group
    func delete(id: String) throws {
        let filename = "\(id).json"
        let fileURL = directoryManager.groupsDirectory.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: fileURL)
    }
}
