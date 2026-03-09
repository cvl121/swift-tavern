import Foundation
import zlib

/// Writes tEXt chunks into PNG data
enum PNGChunkWriter {
    /// Calculate CRC32 for PNG chunk (type + data)
    private static func crc32ForChunk(type: Data, data: Data) -> UInt32 {
        var combined = Data()
        combined.append(type)
        combined.append(data)
        let crc = combined.withUnsafeBytes { buffer in
            zlib.crc32(0, buffer.bindMemory(to: UInt8.self).baseAddress, uInt(combined.count))
        }
        return UInt32(crc)
    }

    /// Insert a tEXt chunk into PNG data (before IEND)
    static func writeTextChunk(to pngData: Data, keyword: String, text: String) throws -> Data {
        guard pngData.isPNG else {
            throw PNGError.invalidSignature
        }

        // Build the tEXt chunk data: keyword\0text
        guard var chunkPayload = keyword.data(using: .isoLatin1) else {
            throw PNGError.invalidChunkData
        }
        chunkPayload.append(0) // null separator
        guard let textData = text.data(using: .isoLatin1) else {
            throw PNGError.invalidChunkData
        }
        chunkPayload.append(textData)

        // Build the full chunk: length + type + data + CRC
        let typeData = "tEXt".data(using: .ascii)!
        let length = UInt32(chunkPayload.count)
        let crc = crc32ForChunk(type: typeData, data: chunkPayload)

        var chunk = Data()
        chunk.append(Data.uint32BigEndian(length))
        chunk.append(typeData)
        chunk.append(chunkPayload)
        chunk.append(Data.uint32BigEndian(crc))

        // Find IEND chunk and insert before it
        // IEND is always last and is 12 bytes: 00000000 49454E44 AE426082
        let iendLength = 12
        guard pngData.count >= iendLength else {
            throw PNGError.invalidChunkData
        }

        var result = Data()
        result.append(pngData[0..<(pngData.count - iendLength)])
        result.append(chunk)
        result.append(pngData[(pngData.count - iendLength)...])

        return result
    }

    /// Remove all tEXt chunks with the given keyword from PNG data
    static func removeTextChunk(from pngData: Data, keyword: String) throws -> Data {
        guard pngData.isPNG else {
            throw PNGError.invalidSignature
        }

        var result = Data()
        result.append(Data.pngSignature)

        var offset = 8

        while offset < pngData.count {
            guard offset + 8 <= pngData.count else { break }

            let length = Int(pngData.readUInt32(at: offset))
            let chunkStart = offset
            offset += 4

            guard offset + 4 <= pngData.count else { break }
            let typeData = pngData[offset..<(offset + 4)]
            let type = String(data: typeData, encoding: .ascii) ?? ""
            offset += 4

            guard offset + length + 4 <= pngData.count else { break }
            let chunkData = pngData[offset..<(offset + length)]
            offset += length + 4 // data + CRC

            // Check if this is a tEXt chunk with our keyword
            if type == "tEXt" {
                if let nullIndex = chunkData.firstIndex(of: 0) {
                    let keyData = chunkData[chunkData.startIndex..<nullIndex]
                    if let key = String(data: keyData, encoding: .isoLatin1), key == keyword {
                        continue // Skip this chunk
                    }
                }
            }

            // Keep the chunk
            result.append(pngData[chunkStart..<offset])
        }

        return result
    }
}
