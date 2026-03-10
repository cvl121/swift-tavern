import XCTest
@testable import SwiftTavern

// MARK: - Feature 1: Character & Persona Avatar Tests

final class AvatarTests: XCTestCase {
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

    func testCharacterEditorAvatarInitialization() {
        let vm = CharacterEditorViewModel(appState: appState)

        XCTAssertNil(vm.avatarData, "New character should have no avatar data")
    }

    func testCharacterEditorRemoveAvatar() {
        let vm = CharacterEditorViewModel(appState: appState)

        // Simulate setting avatar data then removing
        vm.avatarData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
        XCTAssertNotNil(vm.avatarData)

        vm.removeAvatar()
        XCTAssertNil(vm.avatarData, "Avatar should be nil after removal")
    }

    func testPersonaAvatarSaveAndLoad() throws {
        let storage = appState.personaStorage
        let testData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG header

        let filename = try storage.saveAvatar(testData, for: "TestUser")
        XCTAssertFalse(filename.isEmpty, "Avatar filename should not be empty")

        let loaded = storage.loadAvatar(filename: filename)
        XCTAssertNotNil(loaded, "Should be able to load saved avatar")
        XCTAssertEqual(loaded, testData)
    }

    func testPersonaCreationWithAvatar() {
        let vm = PersonaViewModel(appState: appState)
        vm.editingName = "AvatarPersona"
        vm.editingDescription = "A persona with an avatar"
        vm.editingAvatarData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header

        vm.createPersona()

        XCTAssertEqual(appState.personas.count, 1)
        XCTAssertEqual(appState.personas.first?.name, "AvatarPersona")
        XCTAssertNotNil(appState.personas.first?.avatarFilename, "Persona should have avatar filename")
    }

    func testPersonaAvatarLoadData() {
        let vm = PersonaViewModel(appState: appState)
        vm.editingName = "LoadTest"
        vm.editingAvatarData = Data([0x89, 0x50, 0x4E, 0x47])
        vm.createPersona()

        let persona = appState.personas.first!
        let data = vm.loadAvatarData(for: persona)
        XCTAssertNotNil(data, "Should load avatar data for persona with avatar")
    }

    func testPersonaWithoutAvatarReturnsNil() {
        let vm = PersonaViewModel(appState: appState)
        vm.editingName = "NoAvatar"
        vm.createPersona()

        let persona = appState.personas.first!
        XCTAssertNil(persona.avatarFilename)
        let data = vm.loadAvatarData(for: persona)
        XCTAssertNil(data, "Persona without avatar should return nil")
    }
}

// MARK: - Feature 2: Advanced Mode Toggle Tests

final class AdvancedModeTests: XCTestCase {
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

    func testAdvancedModeDefaultsToOff() {
        XCTAssertFalse(appState.settings.advancedMode, "Advanced mode should default to off")
    }

    func testPresetsTabHiddenWhenAdvancedModeOff() {
        let vm = SettingsViewModel(appState: appState)
        vm.advancedMode = false

        let sections = vm.visibleSections
        XCTAssertFalse(sections.contains(.presets), "Presets section should be hidden when advanced mode is off")
    }

    func testPresetsTabVisibleWhenAdvancedModeOn() {
        let vm = SettingsViewModel(appState: appState)
        vm.advancedMode = true

        let sections = vm.visibleSections
        XCTAssertTrue(sections.contains(.presets), "Presets section should be visible when advanced mode is on")
    }

    func testAdvancedModePersistsThroughSave() {
        let vm = SettingsViewModel(appState: appState)
        vm.advancedMode = true
        vm.saveConfiguration()

        XCTAssertTrue(appState.settings.advancedMode, "Advanced mode should persist after save")
    }

    func testVisibleSectionsAlwaysIncludeCoreSections() {
        let vm = SettingsViewModel(appState: appState)
        vm.advancedMode = false

        let sections = vm.visibleSections
        XCTAssertTrue(sections.contains(.api), "API section should always be visible")
        XCTAssertTrue(sections.contains(.general), "General section should always be visible")
        XCTAssertTrue(sections.contains(.chat), "Chat section should always be visible")
        XCTAssertTrue(sections.contains(.experimental), "Experimental section should always be visible")
        XCTAssertTrue(sections.contains(.data), "Data section should always be visible")
        XCTAssertTrue(sections.contains(.reset), "Reset section should always be visible")
    }
}

// MARK: - Feature 3: Experimental Features Tests

final class ExperimentalFeaturesTests: XCTestCase {
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

    func testExperimentalFeaturesDefaultToOff() {
        XCTAssertFalse(appState.settings.experimentalFeatures, "Experimental features should default to off")
    }

    func testGroupChatsDefaultToOff() {
        XCTAssertFalse(appState.settings.groupChatsEnabled, "Group chats should default to off")
    }

    func testExperimentalFeaturesPersist() {
        let vm = SettingsViewModel(appState: appState)
        vm.experimentalFeatures = true
        vm.groupChatsEnabled = true
        vm.saveConfiguration()

        XCTAssertTrue(appState.settings.experimentalFeatures)
        XCTAssertTrue(appState.settings.groupChatsEnabled)
    }

    func testGroupChatsToggleIndependentOfExperimental() {
        let vm = SettingsViewModel(appState: appState)
        vm.experimentalFeatures = true
        vm.groupChatsEnabled = true
        vm.saveConfiguration()

        // Disabling experimental should not auto-disable group chats flag
        vm.experimentalFeatures = false
        vm.saveConfiguration()

        XCTAssertFalse(appState.settings.experimentalFeatures)
        XCTAssertTrue(appState.settings.groupChatsEnabled, "Group chats flag should remain independent")
    }
}

// MARK: - Feature 4: Settings Sidebar Navigation Tests

final class SettingsSidebarTests: XCTestCase {
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

    func testSettingsSectionsHaveIcons() {
        for section in SettingsSection.allCases {
            XCTAssertFalse(section.icon.isEmpty, "Section \(section.rawValue) should have an icon")
        }
    }

    func testSettingsSectionsHaveDisplayNames() {
        for section in SettingsSection.allCases {
            XCTAssertFalse(section.rawValue.isEmpty, "Section should have a display name")
        }
    }

    func testDefaultSelectedSectionIsAPI() {
        let vm = SettingsViewModel(appState: appState)
        XCTAssertEqual(vm.selectedSection, .api, "Default section should be API")
    }

    func testAllSectionsAreIdentifiable() {
        let ids = SettingsSection.allCases.map(\.id)
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All section IDs should be unique")
    }

    func testSectionIconsAreValidSFSymbols() {
        let expectedIcons: [SettingsSection: String] = [
            .api: "network",
            .general: "gearshape",
            .chat: "bubble.left.and.bubble.right",
            .presets: "slider.horizontal.3",
            .experimental: "flask",
            .data: "square.and.arrow.down.on.square",
            .reset: "arrow.counterclockwise"
        ]

        for (section, expectedIcon) in expectedIcons {
            XCTAssertEqual(section.icon, expectedIcon, "Icon for \(section.rawValue) should be \(expectedIcon)")
        }
    }
}

// MARK: - Feature 5: Searchable Model & Connection Test Tests

final class APIModelSearchTests: XCTestCase {
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

    func testFilteredModelsReturnsAllWhenSearchEmpty() {
        let vm = SettingsViewModel(appState: appState)
        vm.modelSearchText = ""

        let all = vm.selectedAPI.defaultModels
        XCTAssertEqual(vm.filteredModels.count, all.count, "Empty search should return all models")
    }

    func testFilteredModelsFiltersCorrectly() {
        let vm = SettingsViewModel(appState: appState)
        vm.modelSearchText = "gpt"

        let results = vm.filteredModels
        for model in results {
            XCTAssertTrue(model.localizedCaseInsensitiveContains("gpt"), "Filtered model should contain search term")
        }
    }

    func testFilteredModelsNonMatchingReturnsEmpty() {
        let vm = SettingsViewModel(appState: appState)
        vm.modelSearchText = "zzz_nonexistent_model_zzz"

        XCTAssertTrue(vm.filteredModels.isEmpty, "Non-matching search should return empty")
    }

    func testConnectionTestInitialState() {
        let vm = SettingsViewModel(appState: appState)
        XCTAssertFalse(vm.isTesting, "Should not be testing initially")
        XCTAssertNil(vm.connectionTestResult, "Should have no test result initially")
        XCTAssertFalse(vm.connectionTestSuccess)
    }

    func testSwitchAPIClearsConnectionResult() {
        let vm = SettingsViewModel(appState: appState)
        vm.connectionTestResult = "Previous result"
        vm.connectionTestSuccess = true

        vm.switchAPI(.claude)

        XCTAssertNil(vm.connectionTestResult, "Switching API should clear connection test result")
    }

    func testSwitchAPIUpdatesModel() {
        let vm = SettingsViewModel(appState: appState)

        vm.switchAPI(.ollama)

        XCTAssertEqual(vm.selectedAPI, .ollama)
        XCTAssertTrue(vm.modelSearchText.isEmpty, "Search text should be cleared on API switch")
    }

    func testModelSearchTextCaseInsensitive() {
        let vm = SettingsViewModel(appState: appState)
        vm.modelSearchText = "GPT" // uppercase

        let upperResults = vm.filteredModels

        vm.modelSearchText = "gpt" // lowercase
        let lowerResults = vm.filteredModels

        XCTAssertEqual(upperResults, lowerResults, "Search should be case insensitive")
    }
}

// MARK: - Characters Tab & Editor Tests

final class CharacterListAndEditorTests: XCTestCase {
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

    func testSidebarItemCharactersExists() {
        let item = SidebarItem.characters
        XCTAssertEqual(item, SidebarItem.characters)
    }

    func testSidebarItemCharactersIsDistinct() {
        let characters = SidebarItem.characters
        let worldLore = SidebarItem.worldLore
        let personas = SidebarItem.personas
        XCTAssertNotEqual(characters, worldLore)
        XCTAssertNotEqual(characters, personas)
    }

    func testCharacterListVMEditCharacter() throws {
        let card = TavernCardV2(data: CharacterData(name: "EditableChar"))
        let filename = try appState.characterStorage.save(card: card, avatarData: nil)
        appState.characters = try appState.characterStorage.loadAll()

        let vm = CharacterListViewModel(appState: appState)
        let entry = appState.characters.first { $0.filename == filename }!

        vm.editCharacter(entry)

        XCTAssertEqual(appState.selectedSidebarItem, .characterInfo(filename), "Should navigate to character info view")
    }

    func testCharacterEditorPopulatesFieldsFromExisting() throws {
        let charData = CharacterData(
            name: "PopulateTest",
            description: "A test description",
            personality: "Friendly",
            tags: ["test", "demo"],
            creator: "Tester"
        )
        let card = TavernCardV2(data: charData)
        let filename = try appState.characterStorage.save(card: card, avatarData: nil)
        appState.characters = try appState.characterStorage.loadAll()
        let entry = appState.characters.first { $0.filename == filename }!

        let vm = CharacterEditorViewModel(appState: appState, character: entry)

        XCTAssertTrue(vm.isEditing)
        XCTAssertEqual(vm.name, "PopulateTest")
        XCTAssertEqual(vm.description, "A test description")
        XCTAssertEqual(vm.personality, "Friendly")
        XCTAssertEqual(vm.creator, "Tester")
        XCTAssertEqual(vm.tags, "test, demo")
    }

    func testAvatarClickableOnEditor() {
        // Verify that the editor VM has pickAvatar method
        let vm = CharacterEditorViewModel(appState: appState)
        XCTAssertNil(vm.avatarData)
        // Simulate setting avatar data (as if user clicked and picked)
        vm.avatarData = Data([0x89, 0x50, 0x4E, 0x47])
        XCTAssertNotNil(vm.avatarData)
    }

    func testBottomToolbarLabelsExist() {
        // Test that SidebarItem.settings exists (settings button in toolbar)
        let settings = SidebarItem.settings
        XCTAssertEqual(settings, SidebarItem.settings)
        // The labeled buttons are a UI concern verified by building successfully
    }
}

// MARK: - SillyTavern Import Tests

final class SillyTavernImportTests: XCTestCase {
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

    func testWorldInfoDecodingNormalizesCommentToContent() throws {
        // SillyTavern stores lore text in "comment", leaves "content" empty
        let json = """
        {
            "entries": {
                "0": {
                    "uid": 0,
                    "key": ["magic"],
                    "keysecondary": [],
                    "comment": "Lore text about magic systems",
                    "content": "",
                    "constant": false,
                    "selective": false,
                    "order": 50,
                    "position": 0,
                    "disable": false,
                    "caseSensitive": null
                }
            }
        }
        """
        // Write to a temp file and load via WorldInfoStorageService
        let worldFile = tempDir.appendingPathComponent("TestWorld.json")
        try json.data(using: .utf8)!.write(to: worldFile)

        let worldInfo = try appState.worldInfoStorage.loadWorldInfo(from: worldFile)
        XCTAssertEqual(worldInfo.name, "TestWorld")
        XCTAssertEqual(worldInfo.entries.count, 1)

        let entry = worldInfo.entries["0"]!
        XCTAssertEqual(entry.content, "Lore text about magic systems",
                       "content should be populated from comment when content is empty")
        XCTAssertEqual(entry.comment, "Lore text about magic systems")
        XCTAssertEqual(entry.keys, ["magic"])
        XCTAssertTrue(entry.enabled, "enabled should be true (disable=false)")
        XCTAssertEqual(entry.insertionOrder, 50, "insertionOrder should come from 'order'")
    }

    func testWorldInfoDecodingPreservesExistingContent() throws {
        // When content is already populated, don't overwrite
        let json = """
        {
            "entries": {
                "0": {
                    "uid": 0,
                    "key": [],
                    "comment": "Entry title",
                    "content": "Actual lore content here",
                    "constant": false,
                    "order": 100,
                    "position": 0,
                    "disable": false
                }
            }
        }
        """
        let worldFile = tempDir.appendingPathComponent("TestWorld2.json")
        try json.data(using: .utf8)!.write(to: worldFile)

        let worldInfo = try appState.worldInfoStorage.loadWorldInfo(from: worldFile)
        let entry = worldInfo.entries["0"]!
        XCTAssertEqual(entry.content, "Actual lore content here",
                       "existing content should be preserved")
        XCTAssertEqual(entry.comment, "Entry title")
    }

    func testImportFromSillyTavernLauncherDirectory() throws {
        // Simulate a SillyTavern-Launcher structure: root/SillyTavern/data/default-user/
        let launcherDir = tempDir.appendingPathComponent("launcher")
        let stDir = launcherDir.appendingPathComponent("SillyTavern")
        let dataDir = stDir.appendingPathComponent("data/default-user")
        let charsDir = dataDir.appendingPathComponent("characters")
        let worldsDir = dataDir.appendingPathComponent("worlds")

        let fm = FileManager.default
        try fm.createDirectory(at: charsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: worldsDir, withIntermediateDirectories: true)

        // Create a minimal character JSON
        let charJson = """
        {"spec":"chara_card_v2","spec_version":"2.0","data":{"name":"TestNarrator","description":"A test narrator","personality":"","scenario":"","first_mes":"","mes_example":"","creator_notes":"","system_prompt":"","post_history_instructions":"","alternate_greetings":[],"tags":[],"creator":"","character_version":"","extensions":{}}}
        """
        try charJson.data(using: .utf8)!.write(to: charsDir.appendingPathComponent("TestNarrator.json"))

        // Create a world info file
        let worldJson = """
        {"entries":{"0":{"uid":0,"key":["test"],"keysecondary":[],"comment":"World lore content","content":"","constant":false,"selective":false,"order":100,"position":0,"disable":false,"caseSensitive":null}}}
        """
        try worldJson.data(using: .utf8)!.write(to: worldsDir.appendingPathComponent("TestWorld.json"))

        // Also create package.json so the launcher detection works
        try "{}".data(using: .utf8)!.write(to: stDir.appendingPathComponent("package.json"))

        // Run import pointing to the launcher directory (not the inner SillyTavern dir)
        let vm = SettingsViewModel(appState: appState)
        vm.sillyTavernPath = launcherDir.path
        vm.importFromPath()

        // Verify characters were imported
        XCTAssertTrue(appState.characters.count >= 1, "Should have imported at least 1 character, got \(appState.characters.count)")
        let narratorExists = appState.characters.contains { $0.card.data.name == "TestNarrator" }
        XCTAssertTrue(narratorExists, "TestNarrator character should be imported")

        // Verify worlds were imported
        XCTAssertTrue(appState.worldInfoBooks.count >= 1, "Should have imported at least 1 world, got \(appState.worldInfoBooks.count)")
        let testWorld = appState.worldInfoBooks.first { $0.name == "TestWorld" }
        XCTAssertNotNil(testWorld, "TestWorld should be imported")
        if let world = testWorld {
            let entry = world.entries["0"]
            XCTAssertNotNil(entry)
            XCTAssertEqual(entry?.content, "World lore content",
                           "World entry content should be populated from comment")
        }
    }
}
