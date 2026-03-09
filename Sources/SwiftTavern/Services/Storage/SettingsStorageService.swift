import Foundation

/// Service for persisting application settings
final class SettingsStorageService {
    private let directoryManager: DataDirectoryManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryManager: DataDirectoryManager) {
        self.directoryManager = directoryManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    /// Load settings from disk, or return defaults
    func load() -> AppSettings {
        let fileURL = directoryManager.settingsFile
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let settings = try? decoder.decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    /// Save settings to disk
    func save(_ settings: AppSettings) throws {
        let fileURL = directoryManager.settingsFile
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
