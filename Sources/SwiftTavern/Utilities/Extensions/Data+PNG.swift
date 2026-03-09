import Foundation

extension Data {
    /// Read a UInt32 from data at the given offset (big-endian, as per PNG spec)
    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { buffer in
            let bytes = buffer.bindMemory(to: UInt8.self)
            return UInt32(bytes[offset]) << 24
                | UInt32(bytes[offset + 1]) << 16
                | UInt32(bytes[offset + 2]) << 8
                | UInt32(bytes[offset + 3])
        }
    }

    /// Write a UInt32 as big-endian bytes
    static func uint32BigEndian(_ value: UInt32) -> Data {
        var data = Data(count: 4)
        data[0] = UInt8((value >> 24) & 0xFF)
        data[1] = UInt8((value >> 16) & 0xFF)
        data[2] = UInt8((value >> 8) & 0xFF)
        data[3] = UInt8(value & 0xFF)
        return data
    }

    /// PNG file signature
    static let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    /// Check if data starts with PNG signature
    var isPNG: Bool {
        count >= 8 && prefix(8) == Data.pngSignature
    }
}
