import Foundation

/// Service for managing character cards on disk
final class CharacterStorageService {
    private let directoryManager: DataDirectoryManager

    init(directoryManager: DataDirectoryManager) {
        self.directoryManager = directoryManager
    }

    /// Load all characters from the characters directory
    func loadAll() throws -> [CharacterEntry] {
        let dir = directoryManager.charactersDirectory
        let fm = FileManager.default

        guard fm.fileExists(atPath: dir.path) else { return [] }

        let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension.lowercased() == "png" }

        var characters: [CharacterEntry] = []
        for file in files {
            if let entry = try? loadCharacter(from: file) {
                characters.append(entry)
            }
        }

        return characters.sorted { $0.card.data.name.lowercased() < $1.card.data.name.lowercased() }
    }

    /// Load a single character from a PNG file
    func loadCharacter(from fileURL: URL) throws -> CharacterEntry {
        let data = try Data(contentsOf: fileURL)
        let card = try CharacterCardParser.parse(from: data)
        return CharacterEntry(filename: fileURL.lastPathComponent, card: card, avatarData: data)
    }

    /// Save a character card (creates or updates)
    func save(card: TavernCardV2, avatarData: Data?, filename: String? = nil) throws -> String {
        let safeName = (filename ?? (card.data.name.sanitizedFilename() + ".png"))
        let fileURL = directoryManager.charactersDirectory.appendingPathComponent(safeName)

        let baseData: Data
        if let avatar = avatarData, avatar.isPNG {
            baseData = avatar
        } else {
            baseData = createMinimalPNG()
        }

        let pngWithCard = try CharacterCardParser.embed(card: card, into: baseData)
        try pngWithCard.write(to: fileURL, options: .atomic)

        return safeName
    }

    /// Delete a character
    func delete(filename: String) throws {
        let fileURL = directoryManager.charactersDirectory.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: fileURL)
    }

    /// Import a character from an external file (PNG with embedded data, or JSON)
    func importCharacter(from sourceURL: URL) throws -> CharacterEntry {
        let data = try Data(contentsOf: sourceURL)
        let ext = sourceURL.pathExtension.lowercased()

        if ext == "json" {
            return try importFromJSON(data: data)
        } else {
            return try importFromPNG(data: data)
        }
    }

    /// Import from a SillyTavern JSON character file
    private func importFromJSON(data: Data) throws -> CharacterEntry {
        let decoder = JSONDecoder()

        // Try TavernCardV2 format first: { "spec": "chara_card_v2", "data": { ... } }
        if let card = try? decoder.decode(TavernCardV2.self, from: data) {
            return try saveAndReturn(card: card)
        }

        // Try bare CharacterData: { "name": "...", "description": "...", ... }
        if let charData = try? decoder.decode(CharacterData.self, from: data) {
            let card = TavernCardV2(data: charData)
            return try saveAndReturn(card: card)
        }

        // Try SillyTavern's character export format which may have extra wrapper fields
        // like "avatar", "chat", "create_date", wrapping the character data at top level
        if let rawDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = rawDict["name"] as? String {
            let charData = CharacterData(
                name: name,
                description: rawDict["description"] as? String ?? "",
                personality: rawDict["personality"] as? String ?? "",
                scenario: rawDict["scenario"] as? String ?? "",
                firstMes: (rawDict["first_mes"] as? String) ?? (rawDict["firstMes"] as? String) ?? "",
                mesExample: (rawDict["mes_example"] as? String) ?? (rawDict["mesExample"] as? String) ?? "",
                creatorNotes: (rawDict["creator_notes"] as? String) ?? (rawDict["creatorNotes"] as? String) ?? "",
                systemPrompt: (rawDict["system_prompt"] as? String) ?? (rawDict["systemPrompt"] as? String) ?? "",
                postHistoryInstructions: (rawDict["post_history_instructions"] as? String) ?? (rawDict["postHistoryInstructions"] as? String) ?? "",
                alternateGreetings: (rawDict["alternate_greetings"] as? [String]) ?? (rawDict["alternateGreetings"] as? [String]) ?? [],
                tags: rawDict["tags"] as? [String] ?? [],
                creator: rawDict["creator"] as? String ?? ""
            )
            let card = TavernCardV2(data: charData)
            return try saveAndReturn(card: card)
        }

        throw PNGError.characterDataNotFound
    }

    /// Import from a PNG file with embedded character data
    private func importFromPNG(data: Data) throws -> CharacterEntry {
        let card = try CharacterCardParser.parse(from: data)
        let filename = card.data.name.sanitizedFilename() + ".png"
        let destURL = directoryManager.charactersDirectory.appendingPathComponent(filename)
        try data.write(to: destURL, options: .atomic)
        return CharacterEntry(filename: filename, card: card, avatarData: data)
    }

    /// Save a parsed card to disk as PNG and return the entry
    private func saveAndReturn(card: TavernCardV2) throws -> CharacterEntry {
        let filename = try save(card: card, avatarData: nil)
        // Reload from disk to get the PNG with embedded data
        let fileURL = directoryManager.charactersDirectory.appendingPathComponent(filename)
        let savedData = try Data(contentsOf: fileURL)
        return CharacterEntry(filename: filename, card: card, avatarData: savedData)
    }

    /// Export a character to a destination URL
    func exportCharacter(filename: String, to destinationURL: URL) throws {
        let sourceURL = directoryManager.charactersDirectory.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    /// Create a minimal valid PNG file (1x1 transparent pixel)
    private func createMinimalPNG() -> Data {
        // Minimal 1x1 transparent PNG
        let pngBytes: [UInt8] = [
            // PNG signature
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            // IHDR chunk
            0x00, 0x00, 0x00, 0x0D, // length = 13
            0x49, 0x48, 0x44, 0x52, // "IHDR"
            0x00, 0x00, 0x00, 0x01, // width = 1
            0x00, 0x00, 0x00, 0x01, // height = 1
            0x08, 0x06,             // bit depth = 8, color type = RGBA
            0x00, 0x00, 0x00,       // compression, filter, interlace
            0x1F, 0x15, 0xC4, 0x89, // CRC
            // IDAT chunk
            0x00, 0x00, 0x00, 0x0A, // length = 10
            0x49, 0x44, 0x41, 0x54, // "IDAT"
            0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00,
            0x00, 0x00, 0x00, 0x05, // CRC placeholder
            // IEND chunk
            0x00, 0x00, 0x00, 0x00, // length = 0
            0x49, 0x45, 0x4E, 0x44, // "IEND"
            0xAE, 0x42, 0x60, 0x82, // CRC
        ]
        return Data(pngBytes)
    }
}
