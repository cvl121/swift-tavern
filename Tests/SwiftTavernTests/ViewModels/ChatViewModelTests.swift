import XCTest
@testable import SwiftTavern

final class ChatViewModelTests: XCTestCase {
    private var tempDir: URL!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        appState = AppState(rootDirectory: tempDir)
        appState.loadAll()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testInitialState() {
        let vm = ChatViewModel(appState: appState)

        XCTAssertTrue(vm.inputText.isEmpty)
        XCTAssertFalse(vm.isGenerating)
        XCTAssertTrue(vm.streamingText.isEmpty)
        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.messages.isEmpty)
    }

    func testCharacterNameDefault() {
        let vm = ChatViewModel(appState: appState)
        XCTAssertEqual(vm.characterName, "Character")
    }

    func testUserNameFromSettings() {
        appState.settings.userName = "TestUser"
        let vm = ChatViewModel(appState: appState)
        XCTAssertEqual(vm.userName, "TestUser")
    }

    func testSendMessageRequiresInput() {
        let vm = ChatViewModel(appState: appState)
        vm.inputText = "   "
        vm.sendMessage()
        // No crash, no message added (input is only whitespace)
        XCTAssertTrue(vm.messages.isEmpty)
    }

    func testNewChatCreatesSession() throws {
        // Create a character first
        let charData = CharacterData(name: "TestChar", firstMes: "Hello!")
        let card = TavernCardV2(data: charData)
        let filename = try appState.characterStorage.save(card: card, avatarData: nil)
        appState.characters = try appState.characterStorage.loadAll()
        appState.selectedCharacter = appState.characters.first { $0.filename == filename }

        let vm = ChatViewModel(appState: appState)
        vm.newChat()

        XCTAssertNotNil(appState.currentChat)
        XCTAssertEqual(appState.currentChat?.metadata.characterName, "TestChar")
    }

    func testChatListEmpty() {
        let vm = ChatViewModel(appState: appState)
        let list = vm.chatList()
        XCTAssertTrue(list.isEmpty)
    }

    func testGenerateResponseWithoutAPIConfig() {
        let vm = ChatViewModel(appState: appState)
        vm.generateResponse()

        // Should set error message since no API is configured
        XCTAssertNotNil(vm.errorMessage)
    }
}
