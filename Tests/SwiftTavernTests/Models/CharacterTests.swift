import XCTest
@testable import SwiftTavern

final class CharacterTests: XCTestCase {
    func testTavernCardV2Encoding() throws {
        let charData = CharacterData(
            name: "TestChar",
            description: "A test character",
            personality: "Friendly",
            scenario: "A test scenario",
            firstMes: "Hello there!",
            mesExample: "<START>\n{{user}}: Hi\n{{char}}: Hello!",
            creatorNotes: "Test notes",
            systemPrompt: "Be helpful",
            postHistoryInstructions: "Remember context",
            alternateGreetings: ["Hey!", "Greetings!"],
            tags: ["test", "demo"],
            creator: "Tester"
        )

        let card = TavernCardV2(data: charData)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(card)
        let decoded = try JSONDecoder().decode(TavernCardV2.self, from: data)

        XCTAssertEqual(decoded.spec, "chara_card_v2")
        XCTAssertEqual(decoded.specVersion, "2.0")
        XCTAssertEqual(decoded.data.name, "TestChar")
        XCTAssertEqual(decoded.data.description, "A test character")
        XCTAssertEqual(decoded.data.personality, "Friendly")
        XCTAssertEqual(decoded.data.scenario, "A test scenario")
        XCTAssertEqual(decoded.data.firstMes, "Hello there!")
        XCTAssertEqual(decoded.data.mesExample, "<START>\n{{user}}: Hi\n{{char}}: Hello!")
        XCTAssertEqual(decoded.data.alternateGreetings, ["Hey!", "Greetings!"])
        XCTAssertEqual(decoded.data.tags, ["test", "demo"])
        XCTAssertEqual(decoded.data.creator, "Tester")
    }

    func testTavernCardV2RoundTrip() throws {
        let charData = CharacterData(
            name: "RoundTrip",
            description: "Test round trip",
            personality: "",
            scenario: "",
            firstMes: "Hi",
            mesExample: "",
            creatorNotes: "",
            systemPrompt: "",
            postHistoryInstructions: "",
            tags: [],
            creator: ""
        )

        let card = TavernCardV2(data: charData)
        let encoded = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(TavernCardV2.self, from: encoded)

        XCTAssertEqual(card, decoded)
    }

    func testCharacterDataFromJSON() throws {
        let json = """
        {
            "spec": "chara_card_v2",
            "spec_version": "2.0",
            "data": {
                "name": "JSONChar",
                "description": "From JSON",
                "personality": "",
                "scenario": "",
                "first_mes": "Hello from JSON",
                "mes_example": "",
                "creator_notes": "",
                "system_prompt": "",
                "post_history_instructions": "",
                "alternate_greetings": [],
                "tags": ["json"],
                "creator": "test"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let card = try JSONDecoder().decode(TavernCardV2.self, from: data)

        XCTAssertEqual(card.data.name, "JSONChar")
        XCTAssertEqual(card.data.firstMes, "Hello from JSON")
        XCTAssertEqual(card.data.tags, ["json"])
    }

    func testAnyCodableTypes() throws {
        let values: [String: AnyCodable] = [
            "string": AnyCodable("hello"),
            "int": AnyCodable(42),
            "bool": AnyCodable(true),
            "double": AnyCodable(3.14),
        ]

        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        XCTAssertEqual(decoded["string"], AnyCodable("hello"))
        XCTAssertEqual(decoded["int"], AnyCodable(42))
        XCTAssertEqual(decoded["bool"], AnyCodable(true))
    }

    func testCharacterEntryIdentifiable() {
        let charData = CharacterData(name: "Test")
        let card = TavernCardV2(data: charData)
        let entry = CharacterEntry(filename: "test.png", card: card, avatarData: nil)

        XCTAssertEqual(entry.id, "test.png")
        XCTAssertEqual(entry.filename, "test.png")
    }
}
