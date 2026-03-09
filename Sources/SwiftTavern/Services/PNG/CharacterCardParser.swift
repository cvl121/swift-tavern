import Foundation

/// Parses character card data from/to PNG files
/// Handles TavernCardV2 format (base64-encoded JSON in 'chara' tEXt chunk)
enum CharacterCardParser {
    /// Extract a TavernCardV2 from PNG data
    static func parse(from pngData: Data) throws -> TavernCardV2 {
        // Try 'chara' keyword (V2 format, most common)
        if let text = try PNGChunkReader.readTextChunk(from: pngData, keyword: "chara") {
            return try decodeCard(from: text)
        }

        // Try 'ccv3' keyword (V3 format)
        if let text = try PNGChunkReader.readTextChunk(from: pngData, keyword: "ccv3") {
            return try decodeCard(from: text)
        }

        throw PNGError.characterDataNotFound
    }

    /// Decode a TavernCardV2 from a base64-encoded JSON string
    private static func decodeCard(from base64String: String) throws -> TavernCardV2 {
        guard let jsonData = Data(base64Encoded: base64String) else {
            throw PNGError.decodingFailed
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(TavernCardV2.self, from: jsonData)
        } catch {
            // Try decoding just the CharacterData (some cards don't wrap in spec envelope)
            if let charData = try? decoder.decode(CharacterData.self, from: jsonData) {
                return TavernCardV2(data: charData)
            }
            throw PNGError.decodingFailed
        }
    }

    /// Embed a TavernCardV2 into PNG data
    static func embed(card: TavernCardV2, into pngData: Data) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonData = try encoder.encode(card)
        let base64String = jsonData.base64EncodedString()

        // Remove existing 'chara' chunk if present
        var cleanedData = pngData
        if (try? PNGChunkReader.readTextChunk(from: pngData, keyword: "chara")) != nil {
            cleanedData = try PNGChunkWriter.removeTextChunk(from: cleanedData, keyword: "chara")
        }

        // Write the new chunk
        return try PNGChunkWriter.writeTextChunk(to: cleanedData, keyword: "chara", text: base64String)
    }
}
