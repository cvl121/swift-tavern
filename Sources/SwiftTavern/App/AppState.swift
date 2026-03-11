import Foundation
import SwiftUI

/// Global application state and dependency container
@Observable
final class AppState {
    // MARK: - Services
    let directoryManager: DataDirectoryManager
    let characterStorage: CharacterStorageService
    let chatStorage: ChatStorageService
    let settingsStorage: SettingsStorageService
    let worldInfoStorage: WorldInfoStorageService
    let personaStorage: PersonaStorageService
    let groupStorage: GroupStorageService
    let groupChatStorage: GroupChatStorageService
    let presetStorage: PresetStorageService

    let devLogger = DevLogger()

    // MARK: - State
    var settings: AppSettings {
        didSet { scheduleSettingsSave() }
    }
    var characters: [CharacterEntry] = []
    var selectedCharacter: CharacterEntry?
    var currentChat: ChatSession?
    var groups: [CharacterGroup] = []
    var selectedGroup: CharacterGroup?
    var worldInfoBooks: [WorldInfo] = []
    var personas: [Persona] = []
    var presets: [ChatPreset] = []
    var activePresetName: String = "Default"
    var isLoading = false
    var errorMessage: String?

    // Toast notifications
    var toastMessage: String?
    var toastIsError = false

    // Auto-save indicator
    var lastSaveTime: Date?
    var isSaving = false
    private var toastDismissTask: DispatchWorkItem?

    func showToast(_ message: String, isError: Bool = false) {
        toastDismissTask?.cancel()
        toastMessage = message
        toastIsError = isError
        let task = DispatchWorkItem { [weak self] in
            self?.toastMessage = nil
        }
        toastDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
    }

    // MARK: - Navigation
    var selectedSidebarItem: SidebarItem?

    // MARK: - Auto-save
    private var settingsSaveTask: DispatchWorkItem?

    init(rootDirectory: URL? = nil) {
        let dirManager = DataDirectoryManager(rootDirectory: rootDirectory)
        self.directoryManager = dirManager
        self.characterStorage = CharacterStorageService(directoryManager: dirManager)
        self.chatStorage = ChatStorageService(directoryManager: dirManager)
        self.settingsStorage = SettingsStorageService(directoryManager: dirManager)
        self.worldInfoStorage = WorldInfoStorageService(directoryManager: dirManager)
        self.personaStorage = PersonaStorageService(directoryManager: dirManager)
        self.groupStorage = GroupStorageService(directoryManager: dirManager)
        self.groupChatStorage = GroupChatStorageService(directoryManager: dirManager)
        self.presetStorage = PresetStorageService(directoryManager: dirManager)
        self.settings = .default

        // Ensure directories exist
        try? dirManager.ensureDirectoriesExist()

        // Load settings
        self.settings = settingsStorage.load()
    }

    /// Load all data from disk asynchronously
    func loadAll() {
        isLoading = true

        Task.detached(priority: .userInitiated) { [self] in
            let chars = (try? characterStorage.loadAll()) ?? []
            let grps = (try? groupStorage.loadAll()) ?? []
            let worlds = (try? worldInfoStorage.loadAll()) ?? []
            let pers = personaStorage.loadAll()
            let pres = presetStorage.loadAll()

            await MainActor.run {
                characters = chars
                groups = grps
                worldInfoBooks = worlds
                personas = pers
                presets = pres
                isLoading = false

                // Create default Assistant character if no characters exist
                if characters.isEmpty {
                    createDefaultAssistant()
                }

                // Restore last session
                restoreSession()
            }
        }
    }

    /// Restore the last active character and chat
    func restoreSession() {
        if let activeCharFilename = settings.activeCharacter,
           let entry = characters.first(where: { $0.filename == activeCharFilename }) {
            selectedCharacter = entry
            selectedSidebarItem = .character(entry.filename)

            // Restore the specific chat that was active for this character
            let charName = entry.card.data.name
            if let activeChatFilename = settings.activeChatPerCharacter[activeCharFilename],
               let session = try? chatStorage.loadChat(characterName: charName, filename: activeChatFilename) {
                currentChat = session
            } else if let chats = try? chatStorage.listChats(for: charName),
                      let mostRecent = chats.first {
                currentChat = try? chatStorage.loadChat(
                    characterName: charName,
                    filename: mostRecent.filename
                )
            }
        }
    }

    /// Track which chat is active for the current character
    func saveActiveChatFilename() {
        guard let charFilename = selectedCharacter?.filename,
              let chatFilename = currentChat?.filename else { return }
        settings.activeChatPerCharacter[charFilename] = chatFilename
    }

    /// Debounced auto-save settings (500ms delay)
    private func scheduleSettingsSave() {
        settingsSaveTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            try? self.settingsStorage.save(self.settings)
        }
        settingsSaveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }

    /// Force immediate save
    func saveSettings() {
        settingsSaveTask?.cancel()
        isSaving = true
        try? settingsStorage.save(settings)
        lastSaveTime = Date()
        isSaving = false
    }

    /// Get the current API configuration
    func currentAPIConfiguration() -> APIConfiguration? {
        let apiType = settings.activeAPI
        let apiKey = settings.apiKeys[apiType.rawValue] ?? ""

        if apiType.requiresAPIKey && apiKey.isEmpty {
            return nil
        }

        let configData = settings.apiConfigurations[apiType.rawValue]
            ?? .defaultConfig(for: apiType)

        return APIConfiguration(
            apiType: apiType,
            apiKey: apiKey,
            baseURL: configData.baseURL,
            model: configData.model.isEmpty ? (apiType.defaultModels.first ?? "") : configData.model,
            generationParams: configData.generationParams
        )
    }

    /// Get the LLM service for the current API
    func currentLLMService() -> LLMService {
        LLMServiceFactory.create(for: settings.activeAPI)
    }

    /// Track active character for session restoration
    func setActiveCharacter(_ entry: CharacterEntry?) {
        selectedCharacter = entry
        settings.activeCharacter = entry?.filename
    }

    /// Create a default "Assistant" character on first launch
    private func createDefaultAssistant() {
        let assistantData = CharacterData(
            name: "Assistant",
            description: "A helpful, knowledgeable AI assistant ready to help with any task.",
            personality: "Friendly, helpful, concise, and knowledgeable.",
            scenario: "",
            firstMes: "Hello! I'm your AI assistant. How can I help you today?",
            mesExample: "",
            creatorNotes: "Default assistant character for SwiftTavern.",
            systemPrompt: "You are a helpful AI assistant. Be friendly, concise, and informative.",
            postHistoryInstructions: "",
            tags: ["assistant", "default"],
            creator: "SwiftTavern"
        )
        let card = TavernCardV2(data: assistantData)
        if let filename = try? characterStorage.save(card: card, avatarData: nil) {
            characters = (try? characterStorage.loadAll()) ?? []
        }
    }
}

enum SidebarItem: Hashable {
    case character(String) // filename
    case group(String) // group id
    case characters // character list/management
    case characterInfo(String) // filename - view/edit character details
    case newCharacter // create new character
    case settings
    case worldLore
    case personas
}
