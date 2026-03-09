import XCTest
@testable import SwiftTavern

final class PNGChunkTests: XCTestCase {
    /// Create a minimal valid PNG for testing
    private func minimalPNG() -> Data {
        Data([
            // PNG signature
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            // IHDR chunk (13 bytes data)
            0x00, 0x00, 0x00, 0x0D, // length
            0x49, 0x48, 0x44, 0x52, // "IHDR"
            0x00, 0x00, 0x00, 0x01, // width = 1
            0x00, 0x00, 0x00, 0x01, // height = 1
            0x08, 0x06,             // bit depth=8, color type=RGBA
            0x00, 0x00, 0x00,       // compression, filter, interlace
            0x1F, 0x15, 0xC4, 0x89, // CRC
            // IDAT chunk (10 bytes data)
            0x00, 0x00, 0x00, 0x0A,
            0x49, 0x44, 0x41, 0x54,
            0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00,
            0xE2, 0x21, 0xBC, 0x33, // CRC
            // IEND chunk
            0x00, 0x00, 0x00, 0x00,
            0x49, 0x45, 0x4E, 0x44,
            0xAE, 0x42, 0x60, 0x82,
        ])
    }

    func testPNGSignatureDetection() {
        let png = minimalPNG()
        XCTAssertTrue(png.isPNG)

        let notPNG = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertFalse(notPNG.isPNG)
    }

    func testReadChunksFromMinimalPNG() throws {
        let png = minimalPNG()
        let chunks = try PNGChunkReader.readChunks(from: png)

        XCTAssertGreaterThanOrEqual(chunks.count, 3)

        let types = chunks.map(\.type)
        XCTAssertTrue(types.contains("IHDR"))
        XCTAssertTrue(types.contains("IDAT"))
        XCTAssertTrue(types.contains("IEND"))
    }

    func testReadTextChunkNotPresent() throws {
        let png = minimalPNG()
        let text = try PNGChunkReader.readTextChunk(from: png, keyword: "chara")
        XCTAssertNil(text)
    }

    func testWriteAndReadTextChunk() throws {
        let png = minimalPNG()

        // Write a text chunk
        let modified = try PNGChunkWriter.writeTextChunk(to: png, keyword: "test", text: "hello world")

        // Verify it's still a valid PNG
        XCTAssertTrue(modified.isPNG)

        // Read it back
        let text = try PNGChunkReader.readTextChunk(from: modified, keyword: "test")
        XCTAssertEqual(text, "hello world")
    }

    func testRemoveTextChunk() throws {
        let png = minimalPNG()

        // Write then remove
        let withChunk = try PNGChunkWriter.writeTextChunk(to: png, keyword: "test", text: "data")
        let withoutChunk = try PNGChunkWriter.removeTextChunk(from: withChunk, keyword: "test")

        let text = try PNGChunkReader.readTextChunk(from: withoutChunk, keyword: "test")
        XCTAssertNil(text)
    }

    func testInvalidPNGThrows() {
        let notPNG = Data([0x00, 0x01, 0x02, 0x03])

        XCTAssertThrowsError(try PNGChunkReader.readChunks(from: notPNG)) { error in
            XCTAssertTrue(error is PNGError)
        }

        XCTAssertThrowsError(try PNGChunkWriter.writeTextChunk(to: notPNG, keyword: "test", text: "data")) { error in
            XCTAssertTrue(error is PNGError)
        }
    }

    func testReadUInt32() {
        let data = Data([0x00, 0x00, 0x00, 0x0D])
        XCTAssertEqual(data.readUInt32(at: 0), 13)

        let data2 = Data([0xFF, 0xFF, 0xFF, 0xFF])
        XCTAssertEqual(data2.readUInt32(at: 0), UInt32.max)
    }

    func testUInt32BigEndian() {
        let data = Data.uint32BigEndian(13)
        XCTAssertEqual(data, Data([0x00, 0x00, 0x00, 0x0D]))

        let max = Data.uint32BigEndian(UInt32.max)
        XCTAssertEqual(max, Data([0xFF, 0xFF, 0xFF, 0xFF]))
    }
}
