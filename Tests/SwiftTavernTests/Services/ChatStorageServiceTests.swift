import XCTest
@testable import SwiftTavern

final class ChatStorageServiceTests: XCTestCase {
    private var tempDir: URL!
    private var directoryManager: DataDirectoryManager!
    private var chatStorage: ChatStorageService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        directoryManager = DataDirectoryManager(rootDirectory: tempDir)
        try? directoryManager.ensureDirectoriesExist()
        chatStorage = ChatStorageService(directoryManager: directoryManager)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testCreateChat() throws {
        let session = try chatStorage.createChat(
            characterName: "TestChar",
            userName: "TestUser",
            firstMessage: "Hello!"
        )

        XCTAssertEqual(session.metadata.userName, "TestUser")
        XCTAssertEqual(session.metadata.characterName, "TestChar")
        XCTAssertEqual(session.messages.count, 1)
        XCTAssertEqual(session.messages.first?.mes, "Hello!")
        XCTAssertEqual(session.messages.first?.name, "TestChar")
        XCTAssertFalse(session.messages.first?.isUser ?? true)
    }

    func testCreateChatWithoutFirstMessage() throws {
        let session = try chatStorage.createChat(
            characterName: "TestChar",
            userName: "TestUser",
            firstMessage: nil
        )

        XCTAssertEqual(session.messages.count, 0)
    }

    func testAppendAndLoadMessages() throws {
        let session = try chatStorage.createChat(
            characterName: "TestChar",
            userName: "TestUser",
            firstMessage: "Hello!"
        )

        // Append a user message
        let userMsg = ChatMessage(name: "TestUser", isUser: true, mes: "How are you?")
        try chatStorage.appendMessage(userMsg, characterName: "TestChar", filename: session.filename)

        // Append an assistant message
        let assistantMsg = ChatMessage(name: "TestChar", isUser: false, mes: "I'm doing great!")
        try chatStorage.appendMessage(assistantMsg, characterName: "TestChar", filename: session.filename)

        // Load and verify
        let loaded = try chatStorage.loadChat(characterName: "TestChar", filename: session.filename)
        XCTAssertEqual(loaded.messages.count, 3) // first_mes + user + assistant
        XCTAssertEqual(loaded.messages[0].mes, "Hello!")
        XCTAssertEqual(loaded.messages[1].mes, "How are you?")
        XCTAssertEqual(loaded.messages[2].mes, "I'm doing great!")
    }

    func testListChats() throws {
        _ = try chatStorage.createChat(characterName: "TestChar", userName: "User", firstMessage: "One")
        _ = try chatStorage.createChat(characterName: "TestChar", userName: "User", firstMessage: "Two")

        let chats = try chatStorage.listChats(for: "TestChar")
        XCTAssertEqual(chats.count, 2)
    }

    func testDeleteChat() throws {
        let session = try chatStorage.createChat(characterName: "TestChar", userName: "User", firstMessage: "Hi")

        try chatStorage.deleteChat(characterName: "TestChar", filename: session.filename)

        let chats = try chatStorage.listChats(for: "TestChar")
        XCTAssertEqual(chats.count, 0)
    }

    func testSearchChats() throws {
        let session = try chatStorage.createChat(characterName: "TestChar", userName: "User", firstMessage: "Hello world")
        let msg = ChatMessage(name: "User", isUser: true, mes: "Tell me about dragons")
        try chatStorage.appendMessage(msg, characterName: "TestChar", filename: session.filename)

        let results = try chatStorage.searchChats(characterName: "TestChar", query: "dragons")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.matchingMessages.count, 1)

        let noResults = try chatStorage.searchChats(characterName: "TestChar", query: "unicorns")
        XCTAssertEqual(noResults.count, 0)
    }

    func testExportChat() throws {
        let session = try chatStorage.createChat(characterName: "TestChar", userName: "User", firstMessage: "Hi")

        let exported = try chatStorage.exportChat(characterName: "TestChar", filename: session.filename)

        XCTAssertTrue(exported.contains("TestChar"))
        XCTAssertTrue(exported.contains("Hi"))
    }

    func testListChatsForNonexistentCharacter() throws {
        let chats = try chatStorage.listChats(for: "NonexistentChar")
        XCTAssertEqual(chats.count, 0)
    }
}
