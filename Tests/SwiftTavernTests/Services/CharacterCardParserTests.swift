import XCTest
@testable import SwiftTavern

final class CharacterCardParserTests: XCTestCase {
    private func minimalPNG() -> Data {
        Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D,
            0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x01,
            0x08, 0x06,
            0x00, 0x00, 0x00,
            0x1F, 0x15, 0xC4, 0x89,
            0x00, 0x00, 0x00, 0x0A,
            0x49, 0x44, 0x41, 0x54,
            0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00,
            0xE2, 0x21, 0xBC, 0x33,
            0x00, 0x00, 0x00, 0x00,
            0x49, 0x45, 0x4E, 0x44,
            0xAE, 0x42, 0x60, 0x82,
        ])
    }

    func testEmbedAndParseCharacterCard() throws {
        let png = minimalPNG()

        let charData = CharacterData(
            name: "EmbedTest",
            description: "Testing embedding",
            personality: "Cheerful",
            scenario: "Test scenario",
            firstMes: "Hi there!",
            mesExample: "",
            creatorNotes: "",
            systemPrompt: "Be nice",
            postHistoryInstructions: "",
            tags: ["test"],
            creator: "TestCreator"
        )

        let card = TavernCardV2(data: charData)

        // Embed
        let pngWithCard = try CharacterCardParser.embed(card: card, into: png)

        // Parse back
        let parsedCard = try CharacterCardParser.parse(from: pngWithCard)

        XCTAssertEqual(parsedCard.spec, "chara_card_v2")
        XCTAssertEqual(parsedCard.data.name, "EmbedTest")
        XCTAssertEqual(parsedCard.data.description, "Testing embedding")
        XCTAssertEqual(parsedCard.data.personality, "Cheerful")
        XCTAssertEqual(parsedCard.data.firstMes, "Hi there!")
        XCTAssertEqual(parsedCard.data.systemPrompt, "Be nice")
        XCTAssertEqual(parsedCard.data.tags, ["test"])
    }

    func testParseFailsWithoutCharacterData() {
        let png = minimalPNG()
        XCTAssertThrowsError(try CharacterCardParser.parse(from: png)) { error in
            XCTAssertTrue(error is PNGError)
        }
    }

    func testReEmbedReplacesExistingData() throws {
        let png = minimalPNG()

        // First embed
        let card1 = TavernCardV2(data: CharacterData(name: "First"))
        let png1 = try CharacterCardParser.embed(card: card1, into: png)

        // Second embed (should replace)
        let card2 = TavernCardV2(data: CharacterData(name: "Second"))
        let png2 = try CharacterCardParser.embed(card: card2, into: png1)

        let parsed = try CharacterCardParser.parse(from: png2)
        XCTAssertEqual(parsed.data.name, "Second")
    }

    func testEmbeddedPNGRemainsValid() throws {
        let png = minimalPNG()
        let card = TavernCardV2(data: CharacterData(name: "Valid"))
        let embedded = try CharacterCardParser.embed(card: card, into: png)

        XCTAssertTrue(embedded.isPNG)

        // Should have IHDR, tEXt, IDAT, IEND at minimum
        let chunks = try PNGChunkReader.readChunks(from: embedded)
        let types = chunks.map(\.type)
        XCTAssertTrue(types.contains("IHDR"))
        XCTAssertTrue(types.contains("tEXt"))
        XCTAssertTrue(types.contains("IEND"))
    }
}
