import Foundation

/// Service for managing World Info books on disk
final class WorldInfoStorageService {
    private let directoryManager: DataDirectoryManager

    init(directoryManager: DataDirectoryManager) {
        self.directoryManager = directoryManager
    }

    /// Load all world info books
    func loadAll() throws -> [WorldInfo] {
        let dir = directoryManager.worldsDirectory
        let fm = FileManager.default

        guard fm.fileExists(atPath: dir.path) else { return [] }

        let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }

        return files.compactMap { url in
            try? loadWorldInfo(from: url)
        }
    }

    /// Load a single world info book
    func loadWorldInfo(from fileURL: URL) throws -> WorldInfo {
        let data = try Data(contentsOf: fileURL)
        var worldInfo = try JSONDecoder().decode(WorldInfo.self, from: data)
        worldInfo.name = fileURL.deletingPathExtension().lastPathComponent
        return worldInfo
    }

    /// Save a world info book
    func save(_ worldInfo: WorldInfo) throws {
        let filename = worldInfo.name.sanitizedFilename() + ".json"
        let fileURL = directoryManager.worldsDirectory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(worldInfo)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Delete a world info book
    func delete(name: String) throws {
        let filename = name.sanitizedFilename() + ".json"
        let fileURL = directoryManager.worldsDirectory.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: fileURL)
    }
}
