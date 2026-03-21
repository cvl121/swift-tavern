import Foundation

/// Service for persisting application settings
final class SettingsStorageService {
    private let directoryManager: DataDirectoryManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Whether the last load fell back to defaults due to corruption
    private(set) var didResetDueToCorruption = false

    init(directoryManager: DataDirectoryManager) {
        self.directoryManager = directoryManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    /// Load settings from disk, or return defaults.
    /// Sets `didResetDueToCorruption` if the file exists but couldn't be decoded.
    func load() -> AppSettings {
        let fileURL = directoryManager.settingsFile
        let fm = FileManager.default

        guard fm.fileExists(atPath: fileURL.path) else {
            return .default
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            didResetDueToCorruption = true
            return .default
        }

        if let settings = try? decoder.decode(AppSettings.self, from: data) {
            return settings
        }

        // File exists but decoding failed — corruption detected
        didResetDueToCorruption = true

        // Try to preserve the corrupted file for diagnosis
        let corruptedURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("settings.corrupted.json")
        try? fm.removeItem(at: corruptedURL)
        try? fm.copyItem(at: fileURL, to: corruptedURL)

        return .default
    }

    /// Save settings to disk, creating a backup of the previous version first.
    func save(_ settings: AppSettings) throws {
        let fileURL = directoryManager.settingsFile
        let fm = FileManager.default

        // Backup existing settings before overwriting
        if fm.fileExists(atPath: fileURL.path) {
            let backupURL = directoryManager.backupsDirectory
                .appendingPathComponent("settings.backup.json")
            try? fm.removeItem(at: backupURL)
            try? fm.copyItem(at: fileURL, to: backupURL)
        }

        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
