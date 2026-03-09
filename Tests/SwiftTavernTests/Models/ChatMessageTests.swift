import XCTest
@testable import SwiftTavern

final class ChatMessageTests: XCTestCase {
    func testChatMessageEncoding() throws {
        let message = ChatMessage(
            name: "TestUser",
            isUser: true,
            mes: "Hello world"
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded.name, "TestUser")
        XCTAssertTrue(decoded.isUser)
        XCTAssertEqual(decoded.mes, "Hello world")
        XCTAssertFalse(decoded.sendDate.isEmpty)
    }

    func testChatMessageFromJSON() throws {
        let json = """
        {
            "name": "CharName",
            "is_user": false,
            "is_system": false,
            "send_date": "2024-01-01T00:00:00.000Z",
            "mes": "Hello from character"
        }
        """
        let data = json.data(using: .utf8)!
        let message = try JSONDecoder().decode(ChatMessage.self, from: data)

        XCTAssertEqual(message.name, "CharName")
        XCTAssertFalse(message.isUser)
        XCTAssertEqual(message.mes, "Hello from character")
        XCTAssertEqual(message.sendDate, "2024-01-01T00:00:00.000Z")
    }

    func testChatMetadataEncoding() throws {
        let metadata = ChatMetadata(
            userName: "User",
            characterName: "Char",
            chatMetadata: ChatMetadataInfo(note: "test note"),
            createDate: "2024-01-01T00:00:00.000Z"
        )

        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(ChatMetadata.self, from: data)

        XCTAssertEqual(decoded.userName, "User")
        XCTAssertEqual(decoded.characterName, "Char")
        XCTAssertEqual(decoded.chatMetadata.note, "test note")
        XCTAssertEqual(decoded.createDate, "2024-01-01T00:00:00.000Z")
    }

    func testChatSessionProperties() {
        let metadata = ChatMetadata(
            userName: "User",
            characterName: "Char",
            chatMetadata: ChatMetadataInfo()
        )
        let messages = [
            ChatMessage(name: "User", isUser: true, mes: "Hello"),
            ChatMessage(name: "Char", isUser: false, mes: "Hi there!"),
        ]

        let session = ChatSession(
            id: "test-id",
            filename: "test.jsonl",
            metadata: metadata,
            messages: messages
        )

        XCTAssertEqual(session.messageCount, 2)
        XCTAssertEqual(session.lastMessage, "Hi there!")
    }

    func testChatMessageIdentifiable() {
        let msg1 = ChatMessage(name: "User", isUser: true, sendDate: "2024-01-01", mes: "Hi")
        let msg2 = ChatMessage(name: "Char", isUser: false, sendDate: "2024-01-02", mes: "Hello")

        XCTAssertNotEqual(msg1.id, msg2.id)
    }
}
