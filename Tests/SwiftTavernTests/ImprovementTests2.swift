import XCTest
import AppKit
@testable import SwiftTavern

// MARK: - #2: CharacterListViewModel Error Feedback Tests

final class CharacterListErrorTests: XCTestCase {
    private var tempDir: URL!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        appState = AppState(rootDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testErrorMessageInitiallyNil() {
        let vm = CharacterListViewModel(appState: appState)
        XCTAssertNil(vm.errorMessage, "errorMessage should initially be nil")
    }

    func testImportInvalidFileUrlSetsErrorMessage() {
        let vm = CharacterListViewModel(appState: appState)

        // Try importing a file that doesn't exist
        let fakeURL = tempDir.appendingPathComponent("nonexistent.png")
        vm.importCharacter(from: fakeURL)

        XCTAssertNotNil(vm.errorMessage, "errorMessage should be set when import fails")
        XCTAssertTrue(vm.errorMessage!.contains("Failed to import character"),
                       "Error message should describe import failure")
    }

    func testImportInvalidFileSetsErrorMessage() throws {
        let vm = CharacterListViewModel(appState: appState)

        // Create a file with invalid content (not a valid PNG or JSON)
        let invalidFile = tempDir.appendingPathComponent("invalid.png")
        try "not a png".data(using: .utf8)!.write(to: invalidFile)

        vm.importCharacter(from: invalidFile)

        XCTAssertNotNil(vm.errorMessage, "errorMessage should be set when import fails with invalid data")
    }

    func testSuccessfulImportClearsErrorMessage() throws {
        let vm = CharacterListViewModel(appState: appState)
        vm.errorMessage = "Previous error"

        // Create a valid character JSON file
        let charJson = """
        {"spec":"chara_card_v2","spec_version":"2.0","data":{"name":"TestChar","description":"","personality":"","scenario":"","first_mes":"Hello","mes_example":"","creator_notes":"","system_prompt":"","post_history_instructions":"","alternate_greetings":[],"tags":[],"creator":"","character_version":"","extensions":{}}}
        """
        let jsonFile = tempDir.appendingPathComponent("TestChar.json")
        try charJson.data(using: .utf8)!.write(to: jsonFile)

        vm.importCharacter(from: jsonFile)

        XCTAssertNil(vm.errorMessage, "errorMessage should be cleared on successful import")
        XCTAssertEqual(appState.characters.count, 1, "Character should be imported")
    }
}

// MARK: - #3: In-Chat Search Tests

final class InChatSearchTests: XCTestCase {
    private var tempDir: URL!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        appState = AppState(rootDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSearchInCurrentChatFindsMatches() {
        let vm = ChatViewModel(appState: appState)
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "User", isUser: true, mes: "Hello world"),
                ChatMessage(name: "Bot", isUser: false, mes: "Hi there"),
                ChatMessage(name: "User", isUser: true, mes: "Tell me about the world")
            ]
        )

        vm.inChatSearchQuery = "world"
        vm.searchInCurrentChat()

        XCTAssertEqual(vm.inChatSearchResults.count, 2, "Should find 2 messages containing 'world'")
        XCTAssertEqual(vm.inChatSearchResults, [0, 2])
    }

    func testSearchInCurrentChatCaseInsensitive() {
        let vm = ChatViewModel(appState: appState)
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "User", isUser: true, mes: "HELLO World"),
                ChatMessage(name: "Bot", isUser: false, mes: "hello world")
            ]
        )

        vm.inChatSearchQuery = "hello"
        vm.searchInCurrentChat()

        XCTAssertEqual(vm.inChatSearchResults.count, 2, "Search should be case insensitive")
    }

    func testSearchInCurrentChatNoResults() {
        let vm = ChatViewModel(appState: appState)
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "User", isUser: true, mes: "Hello")
            ]
        )

        vm.inChatSearchQuery = "zzznotfound"
        vm.searchInCurrentChat()

        XCTAssertTrue(vm.inChatSearchResults.isEmpty)
    }

    func testSearchEmptyQueryClearsResults() {
        let vm = ChatViewModel(appState: appState)
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "User", isUser: true, mes: "Hello world")
            ]
        )

        vm.inChatSearchQuery = "world"
        vm.searchInCurrentChat()
        XCTAssertEqual(vm.inChatSearchResults.count, 1)

        vm.inChatSearchQuery = ""
        vm.searchInCurrentChat()
        XCTAssertTrue(vm.inChatSearchResults.isEmpty)
    }

    func testNextAndPreviousSearchResult() {
        let vm = ChatViewModel(appState: appState)
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "User", isUser: true, mes: "Hello world"),
                ChatMessage(name: "Bot", isUser: false, mes: "Hi"),
                ChatMessage(name: "User", isUser: true, mes: "Another world message")
            ]
        )

        vm.inChatSearchQuery = "world"
        vm.searchInCurrentChat()

        XCTAssertEqual(vm.currentSearchResultIndex, 0)

        vm.nextSearchResult()
        XCTAssertEqual(vm.currentSearchResultIndex, 1)

        vm.nextSearchResult()
        XCTAssertEqual(vm.currentSearchResultIndex, 0, "Should wrap around")

        vm.previousSearchResult()
        XCTAssertEqual(vm.currentSearchResultIndex, 1, "Should wrap around backwards")
    }
}

// MARK: - #4: CharacterEditorViewModel hasUnsavedChanges Tests

final class CharacterEditorUnsavedChangesTests: XCTestCase {
    private var tempDir: URL!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        appState = AppState(rootDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testNewCharacterNoChanges() {
        let vm = CharacterEditorViewModel(appState: appState)
        XCTAssertFalse(vm.hasUnsavedChanges, "New empty character should have no unsaved changes")
    }

    func testNewCharacterWithNameHasChanges() {
        let vm = CharacterEditorViewModel(appState: appState)
        vm.name = "Test"
        XCTAssertTrue(vm.hasUnsavedChanges, "New character with name should have unsaved changes")
    }

    func testNewCharacterWithDescriptionHasChanges() {
        let vm = CharacterEditorViewModel(appState: appState)
        vm.description = "A description"
        XCTAssertTrue(vm.hasUnsavedChanges)
    }

    func testEditingCharacterNoChanges() throws {
        let charData = CharacterData(
            name: "EditTest",
            description: "Original desc",
            personality: "Friendly"
        )
        let card = TavernCardV2(data: charData)
        let filename = try appState.characterStorage.save(card: card, avatarData: nil)
        appState.characters = try appState.characterStorage.loadAll()
        let entry = appState.characters.first { $0.filename == filename }!

        let vm = CharacterEditorViewModel(appState: appState, character: entry)
        XCTAssertFalse(vm.hasUnsavedChanges, "Unmodified editing character should have no unsaved changes")
    }

    func testEditingCharacterWithChanges() throws {
        let charData = CharacterData(
            name: "EditTest",
            description: "Original desc"
        )
        let card = TavernCardV2(data: charData)
        let filename = try appState.characterStorage.save(card: card, avatarData: nil)
        appState.characters = try appState.characterStorage.loadAll()
        let entry = appState.characters.first { $0.filename == filename }!

        let vm = CharacterEditorViewModel(appState: appState, character: entry)
        vm.name = "Modified Name"
        XCTAssertTrue(vm.hasUnsavedChanges, "Modified character should have unsaved changes")
    }

    func testNewCharacterWithAvatarHasChanges() {
        let vm = CharacterEditorViewModel(appState: appState)
        vm.avatarData = Data([0x89, 0x50, 0x4E, 0x47])
        XCTAssertTrue(vm.hasUnsavedChanges, "New character with avatar should have unsaved changes")
    }
}

// MARK: - #5: GroupChatViewModel Edit/Delete Tests

final class GroupChatEditDeleteTests: XCTestCase {
    private var tempDir: URL!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        appState = AppState(rootDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testBeginEditMessage() {
        let vm = GroupChatViewModel(appState: appState)
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Group", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "User", isUser: true, mes: "Hello group"),
                ChatMessage(name: "Alice", isUser: false, mes: "Hi there!")
            ]
        )

        vm.beginEditMessage(at: 1)
        XCTAssertEqual(vm.editingMessageIndex, 1)
        XCTAssertEqual(vm.editingText, "Hi there!")
    }

    func testCancelEdit() {
        let vm = GroupChatViewModel(appState: appState)
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Group", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "Alice", isUser: false, mes: "Hello")
            ]
        )

        vm.beginEditMessage(at: 0)
        vm.cancelEdit()

        XCTAssertNil(vm.editingMessageIndex)
        XCTAssertTrue(vm.editingText.isEmpty)
    }

    func testEditMessage() {
        let vm = GroupChatViewModel(appState: appState)
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Group", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "Alice", isUser: false, mes: "Original text")
            ]
        )

        vm.editMessage(at: 0, newText: "Edited text")
        XCTAssertEqual(appState.currentChat?.messages[0].mes, "Edited text")
    }

    func testDeleteMessage() {
        let vm = GroupChatViewModel(appState: appState)
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Group", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "User", isUser: true, mes: "Hello"),
                ChatMessage(name: "Alice", isUser: false, mes: "Hi")
            ]
        )

        vm.deleteMessage(at: 1)
        XCTAssertEqual(appState.currentChat?.messages.count, 1)
        XCTAssertEqual(appState.currentChat?.messages[0].mes, "Hello")
    }

    func testRequestDeleteShowsConfirmation() {
        let vm = GroupChatViewModel(appState: appState)
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Group", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "Alice", isUser: false, mes: "Hello")
            ]
        )

        vm.requestDeleteMessage(at: 0)
        XCTAssertTrue(vm.showDeleteConfirmation)
        XCTAssertEqual(vm.pendingDeleteIndex, 0)
    }
}

// MARK: - #9: Loading Indicators Tests

final class LoadingIndicatorTests: XCTestCase {
    func testSettingsViewModelHasImportingProperty() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        appState.loadAll()
        let vm = SettingsViewModel(appState: appState)

        XCTAssertFalse(vm.isImporting)
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSettingsViewModelHasExportingProperty() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        appState.loadAll()
        let vm = SettingsViewModel(appState: appState)

        XCTAssertFalse(vm.isExporting)
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - #11: Avatar Size Constants Tests

final class AvatarSizeConstantsTests: XCTestCase {
    func testSizeSmallValue() {
        XCTAssertEqual(AvatarImageView.sizeSmall, 28)
    }

    func testSizeMediumValue() {
        XCTAssertEqual(AvatarImageView.sizeMedium, 36)
    }

    func testSizeLargeValue() {
        XCTAssertEqual(AvatarImageView.sizeLarge, 48)
    }

    func testSizeXLargeValue() {
        XCTAssertEqual(AvatarImageView.sizeXLarge, 80)
    }
}

// MARK: - #12: TypeScale Tests

final class TypeScaleTests: XCTestCase {
    func testTypeScaleValuesExist() {
        // Verify all TypeScale values can be accessed without error
        let _ = TypeScale.caption
        let _ = TypeScale.footnote
        let _ = TypeScale.body
        let _ = TypeScale.bodyMedium
        let _ = TypeScale.subheadline
        let _ = TypeScale.subheadlineMedium
    }
}

// MARK: - #7: EntryPosition DisplayName Tests

final class EntryPositionDisplayNameTests: XCTestCase {
    func testBeforeCharDisplayName() {
        XCTAssertEqual(EntryPosition.beforeChar.displayName, "Before Character")
    }

    func testAfterCharDisplayName() {
        XCTAssertEqual(EntryPosition.afterChar.displayName, "After Character")
    }

    func testBeforeExampleDisplayName() {
        XCTAssertEqual(EntryPosition.beforeExample.displayName, "Before Examples")
    }

    func testAfterExampleDisplayName() {
        XCTAssertEqual(EntryPosition.afterExample.displayName, "After Examples")
    }

    func testAtDepthDisplayName() {
        XCTAssertEqual(EntryPosition.atDepth.displayName, "At Depth")
    }

    func testAllPositionsHaveDisplayNames() {
        for position in EntryPosition.allCases {
            XCTAssertFalse(position.displayName.isEmpty, "\(position) should have a display name")
            XCTAssertNotEqual(position.displayName, position.rawValue,
                              "Display name should differ from raw value for \(position)")
        }
    }
}

// MARK: - #15: Message Bookmarking Tests

final class MessageBookmarkTests: XCTestCase {
    func testBookmarkedDefaultsToFalse() {
        let msg = ChatMessage(name: "User", isUser: true, mes: "Hello")
        XCTAssertFalse(msg.isBookmarked)
    }

    func testBookmarkedEncodesAndDecodes() throws {
        var msg = ChatMessage(name: "User", isUser: true, mes: "Hello")
        msg.isBookmarked = true

        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        XCTAssertTrue(decoded.isBookmarked)
    }

    func testBookmarkedDecodesGracefullyWhenMissing() throws {
        // JSON without is_bookmarked field
        let json = """
        {"name":"User","is_user":true,"is_system":false,"send_date":"2025-01-01T00:00:00Z","mes":"Hello"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        XCTAssertFalse(decoded.isBookmarked, "isBookmarked should default to false when not present")
    }

    func testToggleBookmark() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        let vm = ChatViewModel(appState: appState)

        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "User", isUser: true, mes: "Hello"),
                ChatMessage(name: "Bot", isUser: false, mes: "Hi there")
            ]
        )

        XCTAssertFalse(appState.currentChat!.messages[0].isBookmarked)
        vm.toggleBookmark(at: 0)
        XCTAssertTrue(appState.currentChat!.messages[0].isBookmarked)
        vm.toggleBookmark(at: 0)
        XCTAssertFalse(appState.currentChat!.messages[0].isBookmarked)

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testBookmarkedMessagesComputed() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        let vm = ChatViewModel(appState: appState)

        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "User", isUser: true, mes: "Hello", isBookmarked: true),
                ChatMessage(name: "Bot", isUser: false, mes: "Hi"),
                ChatMessage(name: "User", isUser: true, mes: "World", isBookmarked: true)
            ]
        )

        let bookmarked = vm.bookmarkedMessages
        XCTAssertEqual(bookmarked.count, 2)
        XCTAssertEqual(bookmarked[0].0, 0)
        XCTAssertEqual(bookmarked[1].0, 2)

        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - #18: Chat Branching (Fork) Tests

final class ChatForkTests: XCTestCase {
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

    func testForkFromMessageCreatesNewChat() throws {
        let charData = CharacterData(name: "ForkChar", firstMes: "Hello!")
        let card = TavernCardV2(data: charData)
        let filename = try appState.characterStorage.save(card: card, avatarData: nil)
        appState.characters = try appState.characterStorage.loadAll()
        appState.selectedCharacter = appState.characters.first { $0.filename == filename }

        let vm = ChatViewModel(appState: appState)
        vm.newChat()

        // Add more messages
        appState.currentChat?.messages.append(ChatMessage(name: "User", isUser: true, mes: "Message 1"))
        appState.currentChat?.messages.append(ChatMessage(name: "ForkChar", isUser: false, mes: "Response 1"))
        appState.currentChat?.messages.append(ChatMessage(name: "User", isUser: true, mes: "Message 2"))

        let originalFilename = appState.currentChat?.filename
        XCTAssertEqual(appState.currentChat?.messages.count, 4) // greeting + 3 added

        vm.forkFromMessage(at: 2) // Fork after "Response 1"

        XCTAssertNotEqual(appState.currentChat?.filename, originalFilename, "Should be a new chat")
        XCTAssertEqual(appState.currentChat?.messages.count, 3, "Forked chat should have messages 0...2")
    }
}

// MARK: - #19: Prompt Preview Tests

final class PromptPreviewTests: XCTestCase {
    func testGeneratePromptPreviewPopulatesText() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        appState.loadAll()

        let charData = CharacterData(
            name: "PreviewChar",
            description: "A test character",
            firstMes: "Hello!"
        )
        let card = TavernCardV2(data: charData)
        let filename = try appState.characterStorage.save(card: card, avatarData: nil)
        appState.characters = try appState.characterStorage.loadAll()
        appState.selectedCharacter = appState.characters.first { $0.filename == filename }

        let vm = ChatViewModel(appState: appState)
        vm.newChat()

        vm.generatePromptPreview()

        XCTAssertFalse(vm.promptPreviewText.isEmpty, "Prompt preview text should be populated")
        XCTAssertTrue(vm.promptPreviewText.contains("[system]"), "Should contain system role")

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testGeneratePromptPreviewNoCharacter() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        let vm = ChatViewModel(appState: appState)

        vm.generatePromptPreview()

        XCTAssertEqual(vm.promptPreviewText, "No character selected.")

        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - #21: Token Count Estimation Tests

final class TokenCountEstimationTests: XCTestCase {
    func testEstimatedTokenCountEmpty() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        let vm = ChatViewModel(appState: appState)

        XCTAssertEqual(vm.estimatedTokenCount, 0)

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testEstimatedTokenCountReasonableValues() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        let vm = ChatViewModel(appState: appState)

        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [
                ChatMessage(name: "User", isUser: true, mes: "Hello world this is a test message"),
                ChatMessage(name: "Bot", isUser: false, mes: "Thank you for your message")
            ]
        )

        let count = vm.estimatedTokenCount
        // 7 words + 5 words = 12 words * 1.3 = ~15-16 tokens
        XCTAssertGreaterThan(count, 0)
        XCTAssertLessThan(count, 100, "Token count should be reasonable for a short chat")

        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - #22: Export as Markdown Tests

final class ExportMarkdownTests: XCTestCase {
    func testFormatChatAsMarkdown() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        let vm = ChatViewModel(appState: appState)

        let metadata = ChatMetadata(
            userName: "User",
            characterName: "Bot",
            chatMetadata: ChatMetadataInfo(),
            createDate: "2025-01-01T00:00:00Z"
        )
        let messages = [
            ChatMessage(name: "Bot", isUser: false, mes: "Hello there!"),
            ChatMessage(name: "User", isUser: true, mes: "Hi Bot!")
        ]

        let markdown = vm.formatChatAsMarkdown(characterName: "Bot", metadata: metadata, messages: messages)

        XCTAssertTrue(markdown.contains("# Chat with Bot"))
        XCTAssertTrue(markdown.contains("Date: 2025-01-01T00:00:00Z"))
        XCTAssertTrue(markdown.contains("**Bot:** Hello there!"))
        XCTAssertTrue(markdown.contains("**User:** Hi Bot!"))
        XCTAssertTrue(markdown.contains("---"))

        try? FileManager.default.removeItem(at: tempDir)
    }
}
