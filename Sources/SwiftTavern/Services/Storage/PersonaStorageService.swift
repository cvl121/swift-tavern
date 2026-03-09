import Foundation

/// Service for managing user personas
final class PersonaStorageService {
    private let directoryManager: DataDirectoryManager
    private let personasFile: URL

    init(directoryManager: DataDirectoryManager) {
        self.directoryManager = directoryManager
        self.personasFile = directoryManager.userDirectory.appendingPathComponent("personas.json")
    }

    /// Load all personas
    func loadAll() -> [Persona] {
        guard let data = try? Data(contentsOf: personasFile),
              let personas = try? JSONDecoder().decode([Persona].self, from: data) else {
            return [Persona(name: "User")]
        }
        return personas
    }

    /// Save all personas
    func saveAll(_ personas: [Persona]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(personas)
        try data.write(to: personasFile, options: .atomic)
    }

    /// Save avatar image for a persona
    func saveAvatar(_ imageData: Data, for personaName: String) throws -> String {
        let filename = personaName.sanitizedFilename() + ".png"
        let fileURL = directoryManager.userAvatarsDirectory.appendingPathComponent(filename)
        try imageData.write(to: fileURL, options: .atomic)
        return filename
    }

    /// Load avatar image data for a persona
    func loadAvatar(filename: String) -> Data? {
        let fileURL = directoryManager.userAvatarsDirectory.appendingPathComponent(filename)
        return try? Data(contentsOf: fileURL)
    }
}
