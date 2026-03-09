import Foundation

/// Represents a single PNG chunk
struct PNGChunk {
    let type: String
    let data: Data
}

/// Reads chunks from PNG binary data (pure Swift, no external dependencies)
enum PNGChunkReader {
    /// Extract all chunks from PNG data
    static func readChunks(from pngData: Data) throws -> [PNGChunk] {
        guard pngData.isPNG else {
            throw PNGError.invalidSignature
        }

        var chunks: [PNGChunk] = []
        var offset = 8 // Skip PNG signature

        while offset < pngData.count {
            guard offset + 8 <= pngData.count else { break }

            let length = Int(pngData.readUInt32(at: offset))
            offset += 4

            guard offset + 4 <= pngData.count else { break }
            let typeData = pngData[offset..<(offset + 4)]
            let type = String(data: typeData, encoding: .ascii) ?? ""
            offset += 4

            guard offset + length <= pngData.count else { break }
            let chunkData = pngData[offset..<(offset + length)]
            offset += length

            // Skip CRC
            offset += 4

            chunks.append(PNGChunk(type: type, data: Data(chunkData)))

            if type == "IEND" { break }
        }

        return chunks
    }

    /// Extract a tEXt chunk with the given keyword
    static func readTextChunk(from pngData: Data, keyword: String) throws -> String? {
        let chunks = try readChunks(from: pngData)

        for chunk in chunks where chunk.type == "tEXt" {
            // tEXt chunk format: keyword\0text
            if let nullIndex = chunk.data.firstIndex(of: 0) {
                let keyData = chunk.data[chunk.data.startIndex..<nullIndex]
                guard let key = String(data: keyData, encoding: .isoLatin1), key == keyword else {
                    continue
                }
                let textStart = chunk.data.index(after: nullIndex)
                let textData = chunk.data[textStart...]
                return String(data: textData, encoding: .isoLatin1)
            }
        }

        return nil
    }
}

enum PNGError: Error, LocalizedError {
    case invalidSignature
    case invalidChunkData
    case characterDataNotFound
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidSignature: return "Not a valid PNG file"
        case .invalidChunkData: return "Invalid PNG chunk data"
        case .characterDataNotFound: return "No character data found in PNG"
        case .decodingFailed: return "Failed to decode character data"
        }
    }
}
