import Foundation
import SwiftUI
import AppKit

/// Settings sidebar navigation items
enum SettingsSection: String, CaseIterable, Identifiable {
    case api = "API Provider"
    case general = "General"
    case chat = "Chat"
    case generation = "Generation"
    case personas = "Personas"
    case experimental = "Experimental"
    case data = "Data"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .api: return "network"
        case .general: return "gearshape"
        case .chat: return "bubble.left.and.bubble.right"
        case .generation: return "slider.horizontal.3"
        case .personas: return "person.circle"
        case .experimental: return "flask"
        case .data: return "square.and.arrow.down.on.square"
        }
    }
}

/// ViewModel for application settings
@Observable
final class SettingsViewModel {
    var selectedSection: SettingsSection = .api
    var apiKey = ""
    var showAPIKey = false
    var selectedAPI: APIType
    var model = ""
    var modelSearchText = ""
    var baseURL = ""
    var userName = ""
    var defaultSystemPrompt = ""
    var generationParams: GenerationParameters
    var statusMessage: String?
    var connectionTestResult: String?
    var connectionTestSuccess: Bool = false
    var isTesting = false

    // Toggles
    var advancedMode: Bool
    var experimentalFeatures: Bool
    var groupChatsEnabled: Bool
    var sendOnEnter: Bool
    var theme: AppTheme
    var chatStyle: ChatStyle
    var imageGenerationEnabled: Bool

    // Data import/export state
    var showingDataImporter = false
    var showingPresetImporter = false
    var sillyTavernPath = ""
    var importStatusMessage: String?
    var importWasError = false

    // Toast
    var showToast = false
    var toastMessage = ""
    var toastIsError = false

    // Live OpenRouter models
    var openRouterModels: [String] = []
    var isLoadingModels = false

    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
        self.selectedAPI = appState.settings.activeAPI
        self.userName = appState.settings.userName
        self.defaultSystemPrompt = appState.settings.defaultSystemPrompt
        self.advancedMode = appState.settings.advancedMode
        self.experimentalFeatures = appState.settings.experimentalFeatures
        self.groupChatsEnabled = appState.settings.groupChatsEnabled
        self.sendOnEnter = appState.settings.sendOnEnter
        self.theme = appState.settings.theme
        self.chatStyle = appState.settings.chatStyle
        self.imageGenerationEnabled = appState.settings.imageGenerationEnabled

        let configData = appState.settings.apiConfigurations[appState.settings.activeAPI.rawValue]
            ?? .defaultConfig(for: appState.settings.activeAPI)
        self.model = configData.model
        self.baseURL = configData.baseURL ?? ""
        self.generationParams = configData.generationParams

        // Load existing API key (from cache, no keychain prompt)
        self.apiKey = appState.secretsStorage.getAPIKey(for: appState.settings.activeAPI) ?? ""

        // Fetch live models if OpenRouter is selected
        if selectedAPI == .openrouter {
            fetchOpenRouterModels()
        }
    }

    /// The active model list for the current provider
    private var currentModels: [String] {
        if selectedAPI == .openrouter && !openRouterModels.isEmpty {
            return openRouterModels
        }
        return selectedAPI.defaultModels
    }

    var filteredModels: [String] {
        let models = currentModels
        if modelSearchText.isEmpty { return models }
        return models.filter { $0.localizedCaseInsensitiveContains(modelSearchText) }
    }

    /// Provider categories for OpenRouter (grouped by prefix)
    var modelProviders: [String] {
        guard selectedAPI == .openrouter else { return [] }
        let providers = Set(currentModels.compactMap { $0.components(separatedBy: "/").first })
        return providers.sorted()
    }

    /// Sections visible based on current settings
    var visibleSections: [SettingsSection] {
        var sections: [SettingsSection] = [.api, .general, .chat]
        if advancedMode {
            sections.append(.generation)
        }
        sections.append(.personas)
        sections.append(.experimental)
        sections.append(.data)
        return sections
    }

    func switchAPI(_ apiType: APIType) {
        guard let appState else { return }
        selectedAPI = apiType
        appState.settings.activeAPI = apiType

        let configData = appState.settings.apiConfigurations[apiType.rawValue]
            ?? .defaultConfig(for: apiType)
        model = configData.model
        baseURL = configData.baseURL ?? ""
        generationParams = configData.generationParams
        apiKey = appState.secretsStorage.getAPIKey(for: apiType) ?? ""
        modelSearchText = ""
        connectionTestResult = nil

        if apiType == .openrouter {
            fetchOpenRouterModels()
        }

        appState.saveSettings()
    }

    // MARK: - OpenRouter Model Fetching

    func fetchOpenRouterModels() {
        guard !isLoadingModels else { return }
        isLoadingModels = true

        Task {
            do {
                let url = URL(string: "https://openrouter.ai/api/v1/models")!
                var request = URLRequest(url: url)
                request.timeoutInterval = 10
                let (data, _) = try await URLSession.shared.data(for: request)

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["data"] as? [[String: Any]] {
                    let modelIds = models.compactMap { $0["id"] as? String }.sorted()
                    await MainActor.run {
                        self.openRouterModels = modelIds
                        self.isLoadingModels = false
                    }
                } else {
                    await MainActor.run { self.isLoadingModels = false }
                }
            } catch {
                // Fall back to static list silently
                await MainActor.run { self.isLoadingModels = false }
            }
        }
    }

    func saveAPIKey() {
        guard let appState else { return }
        if apiKey.isEmpty {
            appState.secretsStorage.deleteAPIKey(for: selectedAPI)
        } else {
            try? appState.secretsStorage.saveAPIKey(apiKey, for: selectedAPI)
        }
        statusMessage = "API key saved"
    }

    func saveConfiguration() {
        guard let appState else { return }
        appState.settings.userName = userName
        appState.settings.defaultSystemPrompt = defaultSystemPrompt
        appState.settings.activeModel = model
        appState.settings.advancedMode = advancedMode
        appState.settings.experimentalFeatures = experimentalFeatures
        appState.settings.groupChatsEnabled = groupChatsEnabled
        appState.settings.sendOnEnter = sendOnEnter
        appState.settings.theme = theme
        appState.settings.chatStyle = chatStyle
        appState.settings.imageGenerationEnabled = imageGenerationEnabled

        let configData = APIConfigurationData(
            baseURL: baseURL.isEmpty ? nil : baseURL,
            model: model,
            generationParams: generationParams
        )
        appState.settings.apiConfigurations[selectedAPI.rawValue] = configData

        appState.saveSettings()
        statusMessage = "Settings saved"
    }

    // MARK: - Connection Test

    func testConnection() {
        guard let appState else {
            connectionTestResult = "No app state available"
            connectionTestSuccess = false
            return
        }

        // Save key first
        saveAPIKey()

        guard let config = appState.currentAPIConfiguration() else {
            connectionTestResult = "No API key configured. Enter and save your key first."
            connectionTestSuccess = false
            return
        }

        isTesting = true
        connectionTestResult = nil

        let service = appState.currentLLMService()
        let messages = [
            LLMMessage(role: .user, content: "Say 'Connection successful!' in exactly those words.")
        ]

        Task {
            do {
                var response = ""
                let stream = service.sendMessage(messages: messages, config: config)
                for try await chunk in stream {
                    response += chunk
                }
                let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    connectionTestResult = "Connected. Response: \(String(trimmed.prefix(100)))"
                    connectionTestSuccess = true
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = "Connection failed: \(error.localizedDescription)"
                    connectionTestSuccess = false
                    isTesting = false
                }
            }
        }
    }

    // MARK: - Data Import

    func importSillyTavernData(from url: URL) {
        guard appState != nil else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        importFromSillyTavernDirectory(url)
    }

    func importFromPath() {
        guard !sillyTavernPath.trimmingCharacters(in: .whitespaces).isEmpty else {
            showToastMessage("Please enter a valid SillyTavern path.", isError: true)
            return
        }

        let url = URL(fileURLWithPath: sillyTavernPath.trimmingCharacters(in: .whitespaces))
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            showToastMessage("Path does not exist: \(sillyTavernPath)", isError: true)
            return
        }

        importFromSillyTavernDirectory(url)
    }

    private func importFromSillyTavernDirectory(_ url: URL) {
        guard let appState else { return }
        let fm = FileManager.default
        var importedChars = 0
        var importedChats = 0
        var importedWorlds = 0
        var importedPresets = 0
        var importedPersonas = 0
        var errors: [String] = []

        // Build list of candidate directories to search
        // SillyTavern stores data in multiple possible locations:
        // 1. Standard: characters/, chats/, worlds/ at root
        // 2. User data: data/default-user/characters/, etc.
        // 3. Any user account: data/*/characters/, etc.
        // 4. Default content: default/content/ (bundled content)

        var charDirs: [URL] = []
        var chatDirs: [URL] = []
        var worldDirs: [URL] = []
        var presetDirs: [URL] = []
        var worldInfoFiles: [URL] = []
        var settingsFiles: [URL] = []

        // Standard root directories
        charDirs.append(url.appendingPathComponent("characters"))
        chatDirs.append(url.appendingPathComponent("chats"))
        worldDirs.append(url.appendingPathComponent("worlds"))
        presetDirs.append(url.appendingPathComponent("presets"))

        // data/default-user/ directories
        let defaultUserDir = url.appendingPathComponent("data/default-user")
        charDirs.append(defaultUserDir.appendingPathComponent("characters"))
        chatDirs.append(defaultUserDir.appendingPathComponent("chats"))
        worldDirs.append(defaultUserDir.appendingPathComponent("worlds"))
        presetDirs.append(defaultUserDir.appendingPathComponent("TextGen Settings"))
        presetDirs.append(defaultUserDir.appendingPathComponent("OpenAI Settings"))
        presetDirs.append(defaultUserDir.appendingPathComponent("NovelAI Settings"))
        presetDirs.append(defaultUserDir.appendingPathComponent("KoboldAI Settings"))
        settingsFiles.append(defaultUserDir.appendingPathComponent("settings.json"))

        // Scan data/ for any user account directories
        let dataDir = url.appendingPathComponent("data")
        if let userDirs = try? fm.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: [.isDirectoryKey]) {
            for userDir in userDirs {
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: userDir.path, isDirectory: &isDir), isDir.boolValue else { continue }
                let name = userDir.lastPathComponent
                if name == "default-user" || name.hasPrefix(".") || name == ".gitkeep" { continue }
                charDirs.append(userDir.appendingPathComponent("characters"))
                chatDirs.append(userDir.appendingPathComponent("chats"))
                worldDirs.append(userDir.appendingPathComponent("worlds"))
                presetDirs.append(userDir.appendingPathComponent("TextGen Settings"))
                presetDirs.append(userDir.appendingPathComponent("OpenAI Settings"))
                settingsFiles.append(userDir.appendingPathComponent("settings.json"))
            }
        }

        // default/content/ — bundled content
        let defaultContent = url.appendingPathComponent("default/content")
        if fm.fileExists(atPath: defaultContent.path) {
            // Characters: PNG files at root of default/content
            charDirs.append(defaultContent)
            // Presets subdirectories (all possible preset types)
            for sub in ["openai", "textgen", "kobold", "novel", "instruct", "context", "sysprompt"] {
                presetDirs.append(defaultContent.appendingPathComponent("presets/\(sub)"))
            }
            settingsFiles.append(defaultContent.appendingPathComponent("settings.json"))
            // World info: JSON files at root that have "entries" key
            if let files = try? fm.contentsOfDirectory(at: defaultContent, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension.lowercased() == "json" {
                    let name = file.lastPathComponent.lowercased()
                    // Skip non-world-info files
                    if name == "settings.json" || name == "index.json" || name.contains("workflow") { continue }
                    // Check if it looks like a world info file
                    if let data = try? Data(contentsOf: file),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       dict["entries"] != nil {
                        worldInfoFiles.append(file)
                    }
                }
            }
        }

        // Import characters
        for dir in charDirs where fm.fileExists(atPath: dir.path) {
            let (count, errs) = importCharactersFromDirectory(dir)
            importedChars += count
            errors.append(contentsOf: errs)
        }

        // Import chats
        for dir in chatDirs where fm.fileExists(atPath: dir.path) {
            importedChats += importChatsFromDirectory(dir)
        }

        // Import world info from directories
        for dir in worldDirs where fm.fileExists(atPath: dir.path) {
            let (count, errs) = importWorldsFromDirectory(dir)
            importedWorlds += count
            errors.append(contentsOf: errs)
        }
        // Import individual world info files (from default/content)
        for file in worldInfoFiles {
            do {
                let book = try appState.worldInfoStorage.loadWorldInfo(from: file)
                let existingNames = appState.worldInfoBooks.map(\.name)
                if !existingNames.contains(book.name) {
                    try appState.worldInfoStorage.save(book)
                    importedWorlds += 1
                }
            } catch {
                errors.append("World '\(file.lastPathComponent)': \(error.localizedDescription)")
            }
        }

        // Import presets
        for dir in presetDirs where fm.fileExists(atPath: dir.path) {
            importedPresets += importPresetsFromDirectory(dir)
        }

        // Import settings (personas, user name, etc.) from the first available settings file
        for settingsFile in settingsFiles where fm.fileExists(atPath: settingsFile.path) {
            importedPersonas += importSettingsData(from: settingsFile)
            break
        }

        // Import user avatars
        let avatarDirs = [
            defaultUserDir.appendingPathComponent("User Avatars"),
            url.appendingPathComponent("User Avatars"),
        ]
        for dir in avatarDirs where fm.fileExists(atPath: dir.path) {
            importUserAvatars(from: dir)
        }

        // Reload data in app state
        appState.characters = (try? appState.characterStorage.loadAll()) ?? []
        appState.worldInfoBooks = (try? appState.worldInfoStorage.loadAll()) ?? []
        appState.personas = (try? appState.personaStorage.loadAll()) ?? []

        var parts: [String] = []
        if importedChars > 0 { parts.append("\(importedChars) characters") }
        if importedChats > 0 { parts.append("\(importedChats) chat folders") }
        if importedWorlds > 0 { parts.append("\(importedWorlds) world lore books") }
        if importedPresets > 0 { parts.append("\(importedPresets) presets") }
        if importedPersonas > 0 { parts.append("\(importedPersonas) personas") }

        if parts.isEmpty && errors.isEmpty {
            showToastMessage("No compatible data found at the specified path.", isError: true)
        } else if parts.isEmpty {
            showToastMessage("Import failed: \(errors.joined(separator: "; "))", isError: true)
        } else {
            var msg = "Import successful! Imported \(parts.joined(separator: ", "))."
            if !errors.isEmpty {
                msg += " (\(errors.count) errors skipped)"
            }
            showToastMessage(msg, isError: false)
        }
    }

    private func importUserAvatars(from dir: URL) {
        guard let appState else { return }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "webp"]
        for file in files where imageExts.contains(file.pathExtension.lowercased()) {
            let destDir = appState.directoryManager.userAvatarsDirectory
            let destFile = destDir.appendingPathComponent(file.lastPathComponent)
            if !fm.fileExists(atPath: destFile.path) {
                try? fm.copyItem(at: file, to: destFile)
            }
        }
    }

    private func importCharactersFromDirectory(_ dir: URL) -> (Int, [String]) {
        guard let appState else { return (0, []) }
        let fm = FileManager.default
        var count = 0
        var errors: [String] = []
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return (0, []) }
        let supportedExtensions: Set<String> = ["png", "json"]
        for file in files where supportedExtensions.contains(file.pathExtension.lowercased()) {
            // Skip files that are clearly not character cards
            let name = file.lastPathComponent.lowercased()
            if name == "settings.json" || name == "index.json" || name.contains("workflow") { continue }
            // Skip user-default avatar
            if name == "user-default.png" { continue }
            // Skip directories (SillyTavern has character expression subdirectories)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: file.path, isDirectory: &isDir), isDir.boolValue { continue }

            do {
                _ = try appState.characterStorage.importCharacter(from: file)
                count += 1
            } catch {
                errors.append("Character '\(file.lastPathComponent)': \(error.localizedDescription)")
            }
        }
        return (count, errors)
    }

    private func importChatsFromDirectory(_ dir: URL) -> Int {
        guard let appState else { return 0 }
        let fm = FileManager.default
        var count = 0
        guard let subdirs = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) else { return 0 }
        for subdir in subdirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: subdir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let charName = subdir.lastPathComponent
            let destDir = appState.directoryManager.chatsDirectory.appendingPathComponent(charName)
            try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            if let chatFiles = try? fm.contentsOfDirectory(at: subdir, includingPropertiesForKeys: nil) {
                for chatFile in chatFiles where chatFile.pathExtension.lowercased() == "jsonl" {
                    let destFile = destDir.appendingPathComponent(chatFile.lastPathComponent)
                    if !fm.fileExists(atPath: destFile.path) {
                        try? fm.copyItem(at: chatFile, to: destFile)
                    }
                }
            }
            count += 1
        }
        return count
    }

    private func importWorldsFromDirectory(_ dir: URL) -> (Int, [String]) {
        guard let appState else { return (0, []) }
        let fm = FileManager.default
        var count = 0
        var errors: [String] = []
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return (0, []) }
        for file in files where file.pathExtension.lowercased() == "json" {
            do {
                let book = try appState.worldInfoStorage.loadWorldInfo(from: file)
                let existingNames = appState.worldInfoBooks.map(\.name)
                if !existingNames.contains(book.name) {
                    try appState.worldInfoStorage.save(book)
                    count += 1
                }
            } catch {
                errors.append("World '\(file.lastPathComponent)': \(error.localizedDescription)")
            }
        }
        return (count, errors)
    }

    private func importPresetsFromDirectory(_ dir: URL) -> Int {
        let fm = FileManager.default
        var count = 0
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return 0 }
        for file in files where file.pathExtension.lowercased() == "json" {
            if let data = try? Data(contentsOf: file),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               dict["temperature"] != nil || dict["max_length"] != nil || dict["max_tokens"] != nil {
                // Apply the last preset found (user can import individual presets via Chat section)
                applyPresetDict(dict)
                count += 1
            }
        }
        return count
    }

    /// Import personas and settings from SillyTavern settings.json
    private func importSettingsData(from settingsFile: URL) -> Int {
        guard let appState else { return 0 }
        guard let data = try? Data(contentsOf: settingsFile),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return 0
        }

        var count = 0
        let powerUser = dict["power_user"] as? [String: Any]

        // Import username
        if let username = dict["username"] as? String, !username.isEmpty {
            appState.settings.userName = username
            userName = username
        }

        // Import personas
        // SillyTavern stores personas in two locations:
        // 1. power_user.personas: { "avatar_filename.png": "Persona Name" }
        // 2. power_user.persona_descriptions: { "avatar_filename.png": { "description": "..." } }
        // Also check legacy top-level "personas" key
        let personaNames: [String: String]? = (powerUser?["personas"] as? [String: String])
            ?? (dict["personas"] as? [String: String])
        let personaDescriptions = powerUser?["persona_descriptions"] as? [String: Any]

        if let personaNames = personaNames {
            let existingNames = Set(appState.personas.map(\.name))
            for (avatarKey, name) in personaNames where !name.isEmpty {
                if !existingNames.contains(name) {
                    // Get description from persona_descriptions if available
                    var description = ""
                    if let descEntry = personaDescriptions?[avatarKey] as? [String: Any],
                       let desc = descEntry["description"] as? String {
                        description = desc
                    }
                    let persona = Persona(name: name, description: description)
                    appState.personas.append(persona)
                    count += 1
                }
            }
            if count > 0 {
                try? appState.personaStorage.saveAll(appState.personas)
            }
        }

        // Import persona description as default system prompt context if available
        if let personaDesc = powerUser?["persona_description"] as? String, !personaDesc.isEmpty {
            // Store the active persona description
            let activeAvatar = dict["user_avatar"] as? String ?? ""
            if let personaNames = personaNames, let activeName = personaNames[activeAvatar] {
                // Update the matching persona's description if it was empty
                if let idx = appState.personas.firstIndex(where: { $0.name == activeName }),
                   appState.personas[idx].description.isEmpty {
                    appState.personas[idx].description = personaDesc
                    try? appState.personaStorage.saveAll(appState.personas)
                }
            }
        }

        // Import generation settings from textgenerationwebui_settings
        if let textgenSettings = dict["textgenerationwebui_settings"] as? [String: Any] {
            applyPresetDict(textgenSettings)
        }

        // Import system prompt from default context
        if let defaultPrompt = dict["default_system_prompt"] as? String, !defaultPrompt.isEmpty {
            appState.settings.defaultSystemPrompt = defaultPrompt
            defaultSystemPrompt = defaultPrompt
        }

        return count
    }

    // MARK: - Preset Import

    func importPreset(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                showToastMessage("Invalid preset file format.", isError: true)
                return
            }

            applyPresetDict(dict)
            saveConfiguration()

            let presetName = url.deletingPathExtension().lastPathComponent
            showToastMessage("Imported preset: \(presetName)", isError: false)
        } catch {
            showToastMessage("Failed to import preset: \(error.localizedDescription)", isError: true)
        }
    }

    private func applyPresetDict(_ dict: [String: Any]) {
        if let v = dict["temperature"] as? Double { generationParams.temperature = v }
        if let v = dict["top_p"] as? Double { generationParams.topP = v }
        if let v = dict["top_k"] as? Int { generationParams.topK = v }
        else if let v = dict["top_k"] as? Double { generationParams.topK = Int(v) }

        if let v = dict["max_tokens"] as? Int { generationParams.maxTokens = v }
        else if let v = dict["max_length"] as? Int { generationParams.maxTokens = v }
        else if let v = dict["genamt"] as? Int { generationParams.maxTokens = v }

        if let v = dict["frequency_penalty"] as? Double { generationParams.frequencyPenalty = v }
        else if let v = dict["freq_pen"] as? Double { generationParams.frequencyPenalty = v }

        if let v = dict["presence_penalty"] as? Double { generationParams.presencePenalty = v }
        else if let v = dict["presence_pen"] as? Double { generationParams.presencePenalty = v }

        if let v = dict["repetition_penalty"] as? Double { generationParams.repetitionPenalty = v }
        else if let v = dict["rep_pen"] as? Double { generationParams.repetitionPenalty = v }

        if let v = dict["stream"] as? Bool { generationParams.streamResponse = v }
    }

    // MARK: - Theme

    func applyTheme() {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: - Toast

    func showToastMessage(_ message: String, isError: Bool) {
        toastMessage = message
        toastIsError = isError
        showToast = true
        importStatusMessage = message
        importWasError = isError
    }

    // MARK: - Data Export

    func exportAllData() {
        guard let appState else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose Export Destination"
        panel.message = "Select a folder to export SwiftTavern data into"
        panel.prompt = "Export Here"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let baseURL = panel.url else { return }

        let exportDir = baseURL.appendingPathComponent("SwiftTavern-Export")
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: exportDir, withIntermediateDirectories: true)

            let charsSrc = appState.directoryManager.charactersDirectory
            let charsDst = exportDir.appendingPathComponent("characters")
            if fm.fileExists(atPath: charsSrc.path) && !fm.fileExists(atPath: charsDst.path) {
                try fm.copyItem(at: charsSrc, to: charsDst)
            }

            let chatsSrc = appState.directoryManager.chatsDirectory
            let chatsDst = exportDir.appendingPathComponent("chats")
            if fm.fileExists(atPath: chatsSrc.path) && !fm.fileExists(atPath: chatsDst.path) {
                try fm.copyItem(at: chatsSrc, to: chatsDst)
            }

            let worldsSrc = appState.directoryManager.worldsDirectory
            let worldsDst = exportDir.appendingPathComponent("worlds")
            if fm.fileExists(atPath: worldsSrc.path) && !fm.fileExists(atPath: worldsDst.path) {
                try fm.copyItem(at: worldsSrc, to: worldsDst)
            }

            let userDir = exportDir.appendingPathComponent("user")
            try fm.createDirectory(at: userDir, withIntermediateDirectories: true)
            let settingsSrc = appState.directoryManager.settingsFile
            if fm.fileExists(atPath: settingsSrc.path) {
                let settingsDst = userDir.appendingPathComponent("settings.json")
                if !fm.fileExists(atPath: settingsDst.path) {
                    try fm.copyItem(at: settingsSrc, to: settingsDst)
                }
            }

            showToastMessage("Data exported to \(exportDir.lastPathComponent)", isError: false)
        } catch {
            showToastMessage("Export failed: \(error.localizedDescription)", isError: true)
        }
    }
}
