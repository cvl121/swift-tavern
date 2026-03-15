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

    /// Character filenames that have new unread responses
    var unreadCharacters: Set<String> = []

    /// Cached chat metadata (filenames + dates) per character, loaded lazily on selection
    var chatMetadataCache: [String: [(filename: String, date: Date?)]] = [:]

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

    /// Debounced auto-save settings (500ms delay to reduce serialization during rapid UI changes)
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

    /// Get the image generation service for the current image gen provider
    func imageGenService() -> ImageGenerationService {
        ImageGenServiceFactory.create(for: settings.imageGenerationSettings.provider)
    }

    /// Resolve the effective persona for a character.
    /// Returns character-specific persona if set, otherwise the global active persona.
    func effectivePersona(for character: CharacterEntry? = nil) -> Persona? {
        if let character,
           let personaName = settings.characterPersonas[character.filename],
           let persona = personas.first(where: { $0.name == personaName }) {
            return persona
        }
        return personas.first { $0.name == settings.userName }
    }

    /// Resolve the effective user name for a character.
    /// Returns character-specific persona name if set, otherwise the global userName.
    func effectiveUserName(for character: CharacterEntry? = nil) -> String {
        if let character,
           let personaName = settings.characterPersonas[character.filename],
           personas.contains(where: { $0.name == personaName }) {
            return personaName
        }
        return settings.userName
    }

    /// Get the API key for the current image gen provider.
    /// If useSharedAPIKey is enabled and the provider overlaps with a text provider, uses that key.
    func imageGenAPIKey() -> String {
        let imgSettings = settings.imageGenerationSettings
        // Check for shared key first
        if imgSettings.useSharedAPIKey,
           let textProvider = imgSettings.provider.sharedTextProvider {
            let sharedKey = settings.apiKeys[textProvider.rawValue] ?? ""
            if !sharedKey.isEmpty { return sharedKey }
        }
        // Fall back to dedicated image gen key
        return settings.apiKeys[imgSettings.provider.apiKeySettingsKey] ?? ""
    }

    /// Get the directory for storing generated images for a character
    func generatedImagesDirectory(for characterName: String) -> URL {
        let dir = directoryManager.generatedImagesDirectory
            .appendingPathComponent(characterName.sanitizedFilename(), isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Load chat metadata (filenames + dates) for a character, using cache when available.
    /// This avoids loading full chat sessions until one is actually selected.
    func loadChatMetadata(for characterName: String, forceReload: Bool = false) -> [(filename: String, date: Date?)] {
        let key = characterName.sanitizedFilename()
        if !forceReload, let cached = chatMetadataCache[key] {
            return cached
        }
        let metadata = (try? chatStorage.listChats(for: characterName)) ?? []
        chatMetadataCache[key] = metadata
        return metadata
    }

    /// Invalidate cached chat metadata for a character (call after creating/deleting chats)
    func invalidateChatMetadata(for characterName: String) {
        let key = characterName.sanitizedFilename()
        chatMetadataCache.removeValue(forKey: key)
    }

    /// Track active character for session restoration
    func setActiveCharacter(_ entry: CharacterEntry?) {
        selectedCharacter = entry
        settings.activeCharacter = entry?.filename
        // Clear unread when switching to a character
        if let filename = entry?.filename {
            markRead(characterFilename: filename)
        }
    }

    /// Mark a character's conversation as having an unread response
    func markUnread(characterFilename: String) {
        unreadCharacters.insert(characterFilename)
        updateDockBadge()
    }

    /// Clear the unread state for a character
    func markRead(characterFilename: String) {
        if unreadCharacters.remove(characterFilename) != nil {
            updateDockBadge()
        }
    }

    /// Update the dock icon badge to show number of unread conversations
    private func updateDockBadge() {
        let count = unreadCharacters.count
        NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
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
