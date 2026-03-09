import XCTest
@testable import SwiftTavern

// MARK: - Default Assistant Character Tests

final class DefaultAssistantTests: XCTestCase {
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

    func testDefaultAssistantCreatedOnFirstLaunch() {
        // loadAll should create default Assistant when no characters exist
        appState.loadAll()

        let expectation = XCTestExpectation(description: "Loading")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        XCTAssertFalse(appState.characters.isEmpty, "Should have at least one character")
        let assistant = appState.characters.first { $0.card.data.name == "Assistant" }
        XCTAssertNotNil(assistant, "Default Assistant character should exist")
        XCTAssertEqual(assistant?.card.data.creator, "SwiftTavern")
    }

    func testNoDefaultAssistantWhenCharactersExist() throws {
        // Pre-create a character
        let card = TavernCardV2(data: CharacterData(name: "ExistingChar"))
        _ = try appState.characterStorage.save(card: card, avatarData: nil)

        appState.loadAll()

        let expectation = XCTestExpectation(description: "Loading")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        // Should not create Assistant since characters already exist
        let assistant = appState.characters.first { $0.card.data.name == "Assistant" }
        XCTAssertNil(assistant, "Should not create default Assistant when characters exist")
        XCTAssertEqual(appState.characters.count, 1)
    }
}

// MARK: - Character Export Tests

final class CharacterExportTests: XCTestCase {
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

    func testExportCharacterSetsDocument() throws {
        let card = TavernCardV2(data: CharacterData(name: "ExportTest"))
        let filename = try appState.characterStorage.save(card: card, avatarData: nil)
        appState.characters = try appState.characterStorage.loadAll()

        let vm = CharacterListViewModel(appState: appState)
        let entry = appState.characters.first { $0.filename == filename }!

        vm.exportCharacter(entry)

        XCTAssertTrue(vm.showingExporter)
        XCTAssertNotNil(vm.exportDocument)
        XCTAssertEqual(vm.exportFilename, filename)
    }
}

// MARK: - Chat Export/Import Tests

final class ChatExportImportTests: XCTestCase {
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

    func testExportChat() throws {
        let card = TavernCardV2(data: CharacterData(name: "ChatExportChar", firstMes: "Hello!"))
        let filename = try appState.characterStorage.save(card: card, avatarData: nil)
        appState.characters = try appState.characterStorage.loadAll()
        appState.selectedCharacter = appState.characters.first { $0.filename == filename }

        let chat = try appState.chatStorage.createChat(
            characterName: "ChatExportChar",
            userName: "User",
            firstMessage: "Hello!"
        )
        appState.currentChat = chat

        let vm = ChatViewModel(appState: appState)
        vm.exportCurrentChat()

        XCTAssertTrue(vm.showingChatExporter)
        XCTAssertNotNil(vm.exportDocument)
    }
}

// MARK: - Data Import Tests

final class DataImportTests: XCTestCase {
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

    func testSettingsViewModelImportState() {
        let vm = SettingsViewModel(appState: appState)

        XCTAssertFalse(vm.showingDataImporter)
        XCTAssertFalse(vm.showingPresetImporter)
        XCTAssertNil(vm.importStatusMessage)
    }

    func testImportFromEmptyDirectory() {
        let vm = SettingsViewModel(appState: appState)
        let emptyDir = tempDir.appendingPathComponent("empty-import")
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        vm.importSillyTavernData(from: emptyDir)

        XCTAssertNotNil(vm.importStatusMessage)
        XCTAssertTrue(vm.importStatusMessage?.contains("No compatible data") ?? false)
    }
}

// MARK: - Renamed App Tests

final class AppRenameTests: XCTestCase {
    func testAppSupportDirectoryUsesSwiftTavern() {
        let dir = FileManager.appSupportDirectory
        XCTAssertTrue(dir.path.contains("SwiftTavern"), "App support dir should use SwiftTavern name")
    }

    func testSidebarItemSettingsExists() {
        let item = SidebarItem.settings
        // Settings should be accessible as a sidebar item
        XCTAssertEqual(item, SidebarItem.settings)
    }
}
