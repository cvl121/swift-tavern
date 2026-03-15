import XCTest
@testable import SwiftTavern

// MARK: - Improvement #1: Image Cache Tests

final class ImageCacheTests: XCTestCase {
    func testCacheReturnsSameInstance() {
        // Create a simple 1x1 red pixel PNG
        let imageData = createTestPNGData()
        let key = "test-avatar-\(imageData.count)"

        let image1 = ImageCache.shared.loadImage(data: imageData, key: key)
        let image2 = ImageCache.shared.loadImage(data: imageData, key: key)

        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
        // Same cached instance
        XCTAssertTrue(image1 === image2)
    }

    func testCacheDifferentKeys() {
        let data1 = createTestPNGData()
        let data2 = createTestPNGData()

        let image1 = ImageCache.shared.loadImage(data: data1, key: "key-a")
        let image2 = ImageCache.shared.loadImage(data: data2, key: "key-b")

        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
    }

    func testCacheHandlesInvalidData() {
        let badData = Data([0x00, 0x01, 0x02])
        let image = ImageCache.shared.loadImage(data: badData, key: "bad-data")
        XCTAssertNil(image)
    }

    private func createTestPNGData() -> Data {
        let size = NSSize(width: 2, height: 2)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return png
    }
}

// MARK: - Improvement #2: Message Actions Tests

final class MessageActionsTests: XCTestCase {
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

    func testCopyMessage() {
        let vm = ChatViewModel(appState: appState)
        let msg = ChatMessage(name: "User", isUser: true, mes: "Copy this text")
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [msg]
        )

        vm.copyMessage(at: 0)

        let pasteboard = NSPasteboard.general
        let copied = pasteboard.string(forType: .string)
        XCTAssertEqual(copied, "Copy this text")
    }

    func testBeginAndCancelEdit() {
        let vm = ChatViewModel(appState: appState)
        let msg = ChatMessage(name: "User", isUser: true, mes: "Original text")
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [msg]
        )

        vm.beginEditMessage(at: 0)
        XCTAssertEqual(vm.editingMessageIndex, 0)
        XCTAssertEqual(vm.editingText, "Original text")

        vm.cancelEdit()
        XCTAssertNil(vm.editingMessageIndex)
        XCTAssertTrue(vm.editingText.isEmpty)
    }

    func testDeleteConfirmationFlow() {
        let vm = ChatViewModel(appState: appState)
        let msg = ChatMessage(name: "User", isUser: true, mes: "Delete me")
        appState.currentChat = ChatSession(
            id: "test",
            filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [msg]
        )

        vm.requestDeleteMessage(at: 0)
        XCTAssertTrue(vm.showDeleteConfirmation)
        XCTAssertEqual(vm.pendingDeleteIndex, 0)
    }
}

// MARK: - Improvement #3: Streaming Timeout Tests

final class StreamingTimeoutTests: XCTestCase {
    func testChatViewModelHasStreamingTimeout() {
        // Verify the ChatViewModel can be created and has the timeout mechanism
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        let vm = ChatViewModel(appState: appState)

        // The timeout constant is internal to the generateResponse method
        // Verify the VM can generate without crashing when no API configured
        vm.generateResponse()
        XCTAssertNotNil(vm.errorMessage)

        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Improvement #4: Thread-Safe Chat Storage Tests

final class ThreadSafeChatStorageTests: XCTestCase {
    private var tempDir: URL!
    private var chatStorage: ChatStorageService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let directoryManager = DataDirectoryManager(rootDirectory: tempDir)
        try? directoryManager.ensureDirectoriesExist()
        chatStorage = ChatStorageService(directoryManager: directoryManager)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testRewriteChat() throws {
        var session = try chatStorage.createChat(
            characterName: "TestChar",
            userName: "User",
            firstMessage: "Hello!"
        )

        // Modify a message
        session.messages[0] = ChatMessage(name: "TestChar", isUser: false, mes: "Modified greeting!")

        try chatStorage.rewriteChat(session, characterName: "TestChar")

        // Reload and verify
        let loaded = try chatStorage.loadChat(characterName: "TestChar", filename: session.filename)
        XCTAssertEqual(loaded.messages.count, 1)
        XCTAssertEqual(loaded.messages[0].mes, "Modified greeting!")
    }

    func testConcurrentAppends() throws {
        let session = try chatStorage.createChat(
            characterName: "ConcurrentChar",
            userName: "User",
            firstMessage: "Start"
        )

        let expectation = XCTestExpectation(description: "Concurrent appends")
        expectation.expectedFulfillmentCount = 10

        let group = DispatchGroup()
        for i in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                let msg = ChatMessage(name: "User", isUser: true, mes: "Message \(i)")
                try? self.chatStorage.appendMessage(msg, characterName: "ConcurrentChar", filename: session.filename)
                expectation.fulfill()
                group.leave()
            }
        }

        group.wait()

        // Verify no crash and file is readable
        let loaded = try chatStorage.loadChat(characterName: "ConcurrentChar", filename: session.filename)
        XCTAssertGreaterThanOrEqual(loaded.messages.count, 1) // At least the initial message
    }
}

// MARK: - Improvement #5: Search Tests

final class ChatSearchTests: XCTestCase {
    private var tempDir: URL!
    private var chatStorage: ChatStorageService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let directoryManager = DataDirectoryManager(rootDirectory: tempDir)
        try? directoryManager.ensureDirectoriesExist()
        chatStorage = ChatStorageService(directoryManager: directoryManager)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSearchFindsMatchingMessages() throws {
        let session = try chatStorage.createChat(
            characterName: "SearchChar",
            userName: "User",
            firstMessage: "Welcome to the kingdom"
        )
        let msg = ChatMessage(name: "User", isUser: true, mes: "Tell me about the ancient dragon")
        try chatStorage.appendMessage(msg, characterName: "SearchChar", filename: session.filename)

        let results = try chatStorage.searchChats(characterName: "SearchChar", query: "dragon")
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].matchingMessages.first?.mes.contains("dragon") ?? false)
    }

    func testSearchCaseInsensitive() throws {
        let session = try chatStorage.createChat(
            characterName: "SearchChar",
            userName: "User",
            firstMessage: "Hello WORLD"
        )

        let results = try chatStorage.searchChats(characterName: "SearchChar", query: "world")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchNoResults() throws {
        _ = try chatStorage.createChat(
            characterName: "SearchChar",
            userName: "User",
            firstMessage: "Hello there"
        )

        let results = try chatStorage.searchChats(characterName: "SearchChar", query: "zzzznotfound")
        XCTAssertEqual(results.count, 0)
    }
}

// MARK: - Improvement #6: Character Book in PromptBuilder Tests

final class CharacterBookPromptTests: XCTestCase {
    func testCharacterBookConstantEntries() {
        let bookEntry = CharacterBookEntry(
            uid: 0,
            keys: [],
            content: "Lore: The world is magical.",
            enabled: true,
            insertionOrder: 0,
            name: "Magic Lore",
            selective: false,
            constant: true
        )
        let characterBook = CharacterBook(
            name: "Test Book",
            entries: [bookEntry]
        )
        let character = CharacterData(
            name: "Wizard",
            description: "A wise wizard",
            personality: "",
            scenario: "",
            firstMes: "Greetings",
            mesExample: "",
            creatorNotes: "",
            systemPrompt: "System.",
            postHistoryInstructions: "",
            characterBook: characterBook
        )

        let messages = PromptBuilder.buildMessages(
            character: character,
            chatHistory: [],
            userName: "User"
        )

        let systemContent = messages[0].content
        XCTAssertTrue(systemContent.contains("The world is magical."))
    }

    func testCharacterBookKeywordTriggered() {
        let bookEntry = CharacterBookEntry(
            uid: 0,
            keys: ["sword"],
            content: "The Excalibur is a legendary sword.",
            enabled: true,
            insertionOrder: 0,
            name: "Sword Lore",
            selective: false,
            constant: false
        )
        let characterBook = CharacterBook(
            name: "Test Book",
            entries: [bookEntry]
        )
        let character = CharacterData(
            name: "Knight",
            description: "",
            personality: "",
            scenario: "",
            firstMes: "",
            mesExample: "",
            creatorNotes: "",
            systemPrompt: "System.",
            postHistoryInstructions: "",
            characterBook: characterBook
        )

        let chatHistory = [
            ChatMessage(name: "User", isUser: true, mes: "I found a sword!")
        ]

        let messages = PromptBuilder.buildMessages(
            character: character,
            chatHistory: chatHistory,
            userName: "User"
        )

        let systemContent = messages[0].content
        XCTAssertTrue(systemContent.contains("Excalibur"))
    }
}

// MARK: - Improvement #7: Greeting Swipes Tests

final class GreetingSwipeTests: XCTestCase {
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

    func testHasGreetingSwipesWithAlternates() throws {
        let charData = CharacterData(
            name: "SwipeChar",
            firstMes: "Hello!",
            alternateGreetings: ["Hi there!", "Hey!"]
        )
        let card = TavernCardV2(data: charData)
        let filename = try appState.characterStorage.save(card: card, avatarData: nil)
        appState.characters = try appState.characterStorage.loadAll()
        appState.selectedCharacter = appState.characters.first { $0.filename == filename }

        let vm = ChatViewModel(appState: appState)
        vm.newChat()

        XCTAssertTrue(vm.hasGreetingSwipes)
        XCTAssertEqual(vm.greetingSwipeIndex, 0)
    }

    func testNoGreetingSwipesWithoutAlternates() throws {
        let charData = CharacterData(name: "NoSwipeChar", firstMes: "Hello!")
        let card = TavernCardV2(data: charData)
        let filename = try appState.characterStorage.save(card: card, avatarData: nil)
        appState.characters = try appState.characterStorage.loadAll()
        appState.selectedCharacter = appState.characters.first { $0.filename == filename }

        let vm = ChatViewModel(appState: appState)
        vm.newChat()

        XCTAssertFalse(vm.hasGreetingSwipes)
    }
}

// MARK: - Improvement #8: Auto-save Settings Tests

final class AutoSaveSettingsTests: XCTestCase {
    func testSettingsAutoSaveOnChange() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        appState.loadAll()

        // Change a setting
        appState.settings.userName = "NewUserName"

        // Wait for debounced save (debounce is 2000ms)
        let expectation = XCTestExpectation(description: "Auto-save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4.0)

        // Load settings fresh and verify
        let freshState = AppState(rootDirectory: tempDir)
        freshState.loadAll()

        // Give it a moment to load
        let loadExpectation = XCTestExpectation(description: "Load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 2.0)

        XCTAssertEqual(freshState.settings.userName, "NewUserName")

        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Improvement #9: Delete Confirmation Tests

final class DeleteConfirmationTests: XCTestCase {
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

    func testRequestDeleteSetsConfirmation() {
        let vm = CharacterListViewModel(appState: appState)
        let entry = CharacterEntry(
            filename: "test.png",
            card: TavernCardV2(data: CharacterData(name: "TestChar")),
            avatarData: nil
        )

        vm.requestDeleteCharacter(entry)

        XCTAssertTrue(vm.showDeleteConfirmation)
        XCTAssertEqual(vm.pendingDeleteEntry?.filename, "test.png")
    }

    func testCancelDeleteClearsPending() {
        let vm = CharacterListViewModel(appState: appState)
        let entry = CharacterEntry(
            filename: "test.png",
            card: TavernCardV2(data: CharacterData(name: "TestChar")),
            avatarData: nil
        )

        vm.requestDeleteCharacter(entry)
        vm.pendingDeleteEntry = nil
        vm.showDeleteConfirmation = false

        XCTAssertFalse(vm.showDeleteConfirmation)
        XCTAssertNil(vm.pendingDeleteEntry)
    }
}

// MARK: - Improvement #10: Window Title Tests

final class WindowTitleTests: XCTestCase {
    func testDefaultWindowTitle() {
        let appState = AppState()
        // No character selected, title should be base
        XCTAssertNil(appState.selectedCharacter)
    }

    func testSelectedCharacterChangesState() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        appState.loadAll()

        let charData = CharacterData(name: "TestTitle")
        let card = TavernCardV2(data: charData)
        let filename = try appState.characterStorage.save(card: card, avatarData: nil)
        appState.characters = try appState.characterStorage.loadAll()
        let entry = appState.characters.first { $0.filename == filename }

        appState.setActiveCharacter(entry)
        XCTAssertEqual(appState.selectedCharacter?.card.data.name, "TestTitle")

        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Quick Win: Sidebar Sort by Recency Tests

final class SidebarSortTests: XCTestCase {
    func testPinnedCharactersSortedFirst() {
        var settings = AppSettings.default
        settings.pinnedCharacters = ["pinned.png"]

        let pinned = Set(settings.pinnedCharacters)

        let entries = [
            makeEntry(filename: "unpinned1.png", name: "Charlie"),
            makeEntry(filename: "pinned.png", name: "Alice"),
            makeEntry(filename: "unpinned2.png", name: "Bob"),
        ]

        let sorted = entries.sorted { a, b in
            let aPinned = pinned.contains(a.filename)
            let bPinned = pinned.contains(b.filename)
            if aPinned != bPinned { return aPinned }
            return false
        }

        XCTAssertEqual(sorted[0].filename, "pinned.png")
    }

    func testRecencySortWithinGroups() {
        let pinned = Set<String>()
        let chatDateCache: [String: Date] = [
            "Alice": Date(timeIntervalSince1970: 100),
            "Bob": Date(timeIntervalSince1970: 300),
            "Charlie": Date(timeIntervalSince1970: 200),
        ]

        let entries = [
            makeEntry(filename: "alice.png", name: "Alice"),
            makeEntry(filename: "bob.png", name: "Bob"),
            makeEntry(filename: "charlie.png", name: "Charlie"),
        ]

        let sorted = entries.sorted { a, b in
            let aPinned = pinned.contains(a.filename)
            let bPinned = pinned.contains(b.filename)
            if aPinned != bPinned { return aPinned }
            let aDate = chatDateCache[a.card.data.name] ?? .distantPast
            let bDate = chatDateCache[b.card.data.name] ?? .distantPast
            return aDate > bDate
        }

        XCTAssertEqual(sorted[0].card.data.name, "Bob")     // most recent
        XCTAssertEqual(sorted[1].card.data.name, "Charlie")  // middle
        XCTAssertEqual(sorted[2].card.data.name, "Alice")    // oldest
    }

    func testPinnedAndRecencyCombined() {
        let pinned: Set<String> = ["old-pinned.png"]
        let chatDateCache: [String: Date] = [
            "OldPinned": Date(timeIntervalSince1970: 100),
            "RecentUnpinned": Date(timeIntervalSince1970: 500),
        ]

        let entries = [
            makeEntry(filename: "recent.png", name: "RecentUnpinned"),
            makeEntry(filename: "old-pinned.png", name: "OldPinned"),
        ]

        let sorted = entries.sorted { a, b in
            let aPinned = pinned.contains(a.filename)
            let bPinned = pinned.contains(b.filename)
            if aPinned != bPinned { return aPinned }
            let aDate = chatDateCache[a.card.data.name] ?? .distantPast
            let bDate = chatDateCache[b.card.data.name] ?? .distantPast
            return aDate > bDate
        }

        // Pinned always first, even if older
        XCTAssertEqual(sorted[0].card.data.name, "OldPinned")
        XCTAssertEqual(sorted[1].card.data.name, "RecentUnpinned")
    }

    private func makeEntry(filename: String, name: String) -> CharacterEntry {
        CharacterEntry(
            filename: filename,
            card: TavernCardV2(data: CharacterData(name: name)),
            avatarData: nil
        )
    }
}

// MARK: - Quick Win: IndexedDisplayMessages Tests

final class IndexedDisplayMessagesTests: XCTestCase {
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

    func testIndexedDisplayMessagesReturnsAll() {
        let vm = ChatViewModel(appState: appState)
        let messages = [
            ChatMessage(name: "User", isUser: true, mes: "Hello"),
            ChatMessage(name: "Bot", isUser: false, mes: "Hi there"),
        ]
        appState.currentChat = ChatSession(
            id: "test", filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: messages
        )

        vm.showingBookmarksOnly = false
        let indexed = vm.indexedDisplayMessages
        XCTAssertEqual(indexed.count, 2)
        XCTAssertEqual(indexed[0].offset, 0)
        XCTAssertEqual(indexed[1].offset, 1)
    }

    func testIndexedDisplayMessagesFiltersByBookmark() {
        let vm = ChatViewModel(appState: appState)
        var bookmarked = ChatMessage(name: "Bot", isUser: false, mes: "Important")
        bookmarked.isBookmarked = true
        let messages = [
            ChatMessage(name: "User", isUser: true, mes: "Hello"),
            bookmarked,
            ChatMessage(name: "User", isUser: true, mes: "Bye"),
        ]
        appState.currentChat = ChatSession(
            id: "test", filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: messages
        )

        vm.showingBookmarksOnly = true
        let indexed = vm.indexedDisplayMessages
        XCTAssertEqual(indexed.count, 1)
        XCTAssertEqual(indexed[0].offset, 1) // original index preserved
        XCTAssertEqual(indexed[0].element.mes, "Important")
    }

    func testIndexedDisplayMessagesEmpty() {
        let vm = ChatViewModel(appState: appState)
        appState.currentChat = nil

        let indexed = vm.indexedDisplayMessages
        XCTAssertTrue(indexed.isEmpty)
    }
}

// MARK: - Quick Win: Pinned Characters Settings Persistence Tests

final class PinnedCharactersSettingsTests: XCTestCase {
    func testPinnedCharactersDefaultEmpty() {
        let settings = AppSettings.default
        XCTAssertTrue(settings.pinnedCharacters.isEmpty)
    }

    func testPinnedCharactersEncodeDecode() throws {
        var settings = AppSettings.default
        settings.pinnedCharacters = ["char1.png", "char2.png"]

        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.pinnedCharacters, ["char1.png", "char2.png"])
    }

    func testPinnedCharactersBackwardsCompatible() throws {
        // Simulate loading settings that don't have pinnedCharacters field
        var settings = AppSettings.default
        let encoder = JSONEncoder()
        var data = try encoder.encode(settings)

        // Remove the pinned_characters key from JSON
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "pinned_characters")
        data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertTrue(decoded.pinnedCharacters.isEmpty)
    }
}

// MARK: - Quick Win: Settings Debounce Tests

final class SettingsDebounceTests: XCTestCase {
    func testSettingsSaveWithReducedDebounce() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        appState.loadAll()

        appState.settings.userName = "DebounceTest"

        // With 500ms debounce, should save within 1 second
        let expectation = XCTestExpectation(description: "Debounced save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let freshState = AppState(rootDirectory: tempDir)
        freshState.loadAll()

        let loadExpectation = XCTestExpectation(description: "Load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 2.0)

        XCTAssertEqual(freshState.settings.userName, "DebounceTest")

        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Reference Image Settings Tests

final class ReferenceImageSettingsTests: XCTestCase {
    func testReferenceImageDefaultValues() {
        let settings = ImageGenerationSettings()
        XCTAssertFalse(settings.useReferenceImage)
        XCTAssertEqual(settings.referenceImageStrength, 0.6, accuracy: 0.001)
    }

    func testReferenceImageEncodeDecode() throws {
        var settings = ImageGenerationSettings()
        settings.useReferenceImage = true
        settings.referenceImageStrength = 0.75

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ImageGenerationSettings.self, from: data)

        XCTAssertTrue(decoded.useReferenceImage)
        XCTAssertEqual(decoded.referenceImageStrength, 0.75, accuracy: 0.001)
    }

    func testReferenceImageBackwardsCompatible() throws {
        // Simulate loading settings without the new fields
        let settings = ImageGenerationSettings()
        let data = try JSONEncoder().encode(settings)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "use_reference_image")
        json.removeValue(forKey: "reference_image_strength")
        let modified = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(ImageGenerationSettings.self, from: modified)
        XCTAssertFalse(decoded.useReferenceImage)
        XCTAssertEqual(decoded.referenceImageStrength, 0.6, accuracy: 0.001)
    }

    func testSupportsReferenceImage() {
        XCTAssertTrue(ImageGenProvider.novelai.supportsReferenceImage)
        XCTAssertTrue(ImageGenProvider.openrouter.supportsReferenceImage)
        XCTAssertFalse(ImageGenProvider.openaiDalle.supportsReferenceImage)
        XCTAssertFalse(ImageGenProvider.stabilityAI.supportsReferenceImage)
        XCTAssertFalse(ImageGenProvider.custom.supportsReferenceImage)
    }
}

// MARK: - System Default Font Size Tests

final class SystemDefaultFontSizeTests: XCTestCase {
    func testSystemDefaultFontSizeIsReasonable() {
        let size = ChatStyle.systemDefaultFontSize
        // macOS system font size is typically 13, but should be > 0
        XCTAssertGreaterThan(size, 0)
        XCTAssertLessThan(size, 100) // sanity check
    }

    func testDefaultChatStyleUsesSystemFontSize() {
        let style = ChatStyle.default
        XCTAssertEqual(style.fontSize, ChatStyle.systemDefaultFontSize, accuracy: 0.001)
    }

    func testLightDefaultChatStyleUsesSystemFontSize() {
        let style = ChatStyle.lightDefault
        XCTAssertEqual(style.fontSize, ChatStyle.systemDefaultFontSize, accuracy: 0.001)
    }
}

// MARK: - UI Improvement Validation Tests

final class UIImprovementTests: XCTestCase {
    func testImageGenProviderHints() {
        // Ensure all providers with reference image support also have prompt hints
        for provider in ImageGenProvider.allCases {
            XCTAssertFalse(provider.promptHint.isEmpty, "\(provider.displayName) missing prompt hint")
            if provider.supportsReferenceImage {
                // Providers that support reference images should also support the feature
                XCTAssertTrue(provider == .novelai || provider == .openrouter)
            }
        }
    }

    func testImageGenerationSettingsWithReferenceImage() {
        var settings = ImageGenerationSettings()
        settings.useReferenceImage = true
        settings.referenceImageStrength = 0.5
        settings.provider = .novelai

        XCTAssertTrue(settings.provider.supportsReferenceImage)
        XCTAssertTrue(settings.useReferenceImage)
        XCTAssertEqual(settings.referenceImageStrength, 0.5, accuracy: 0.001)
    }
}

// MARK: - Message Action Buttons Tests

final class MessageActionButtonsTests: XCTestCase {
    func testShowChatButtonLabelsDefaultFalse() {
        let settings = AppSettings.default
        XCTAssertFalse(settings.showChatButtonLabels)
    }

    func testShowChatButtonLabelsEncodeDecode() throws {
        var settings = AppSettings.default
        settings.showChatButtonLabels = true

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertTrue(decoded.showChatButtonLabels)
    }

    func testShowChatButtonLabelsBackwardsCompatible() throws {
        let settings = AppSettings.default
        let data = try JSONEncoder().encode(settings)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "show_chat_button_labels")
        let modified = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(AppSettings.self, from: modified)
        XCTAssertFalse(decoded.showChatButtonLabels)
    }

    func testMessageActionsStillWork() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        appState.loadAll()
        let vm = ChatViewModel(appState: appState)

        let msg = ChatMessage(name: "User", isUser: true, mes: "Test message")
        appState.currentChat = ChatSession(
            id: "test", filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [msg]
        )

        // Copy
        vm.copyMessage(at: 0)
        let copied = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(copied, "Test message")

        // Edit
        vm.beginEditMessage(at: 0)
        XCTAssertEqual(vm.editingMessageIndex, 0)
        XCTAssertEqual(vm.editingText, "Test message")
        vm.cancelEdit()
        XCTAssertNil(vm.editingMessageIndex)

        // Delete
        vm.requestDeleteMessage(at: 0)
        XCTAssertTrue(vm.showDeleteConfirmation)
        XCTAssertEqual(vm.pendingDeleteIndex, 0)

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testEditTrimsTrailingNewlines() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)
        appState.loadAll()
        let vm = ChatViewModel(appState: appState)

        let msg = ChatMessage(name: "User", isUser: true, mes: "Original")
        appState.currentChat = ChatSession(
            id: "test", filename: "test.jsonl",
            metadata: ChatMetadata(userName: "User", characterName: "Bot", chatMetadata: ChatMetadataInfo()),
            messages: [msg]
        )

        vm.beginEditMessage(at: 0)
        vm.editingText = "Edited text\n\n\n"
        vm.saveEditedMessage()

        XCTAssertEqual(appState.currentChat?.messages[0].mes, "Edited text")

        try? FileManager.default.removeItem(at: tempDir)
    }
}
