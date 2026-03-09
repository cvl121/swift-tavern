import Foundation

/// Application settings
/// App-wide theme options
enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

struct AppSettings: Codable {
    var activeAPI: APIType
    var activeModel: String
    var userName: String
    var activePersona: String?
    var activeCharacter: String?
    var defaultSystemPrompt: String
    var apiConfigurations: [String: APIConfigurationData]
    var advancedMode: Bool
    var experimentalFeatures: Bool
    var groupChatsEnabled: Bool
    var sendOnEnter: Bool
    var theme: AppTheme
    var hasCompletedOnboarding: Bool
    var chatStyle: ChatStyle
    var imageGenerationEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case activeAPI = "active_api"
        case activeModel = "active_model"
        case userName = "user_name"
        case activePersona = "active_persona"
        case activeCharacter = "active_character"
        case defaultSystemPrompt = "default_system_prompt"
        case apiConfigurations = "api_configurations"
        case advancedMode = "advanced_mode"
        case experimentalFeatures = "experimental_features"
        case groupChatsEnabled = "group_chats_enabled"
        case sendOnEnter = "send_on_enter"
        case theme
        case hasCompletedOnboarding = "has_completed_onboarding"
        case chatStyle = "chat_style"
        case imageGenerationEnabled = "image_generation_enabled"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeAPI = try container.decode(APIType.self, forKey: .activeAPI)
        activeModel = try container.decode(String.self, forKey: .activeModel)
        userName = try container.decode(String.self, forKey: .userName)
        activePersona = try container.decodeIfPresent(String.self, forKey: .activePersona)
        activeCharacter = try container.decodeIfPresent(String.self, forKey: .activeCharacter)
        defaultSystemPrompt = try container.decode(String.self, forKey: .defaultSystemPrompt)
        apiConfigurations = try container.decode([String: APIConfigurationData].self, forKey: .apiConfigurations)
        advancedMode = try container.decode(Bool.self, forKey: .advancedMode)
        experimentalFeatures = try container.decode(Bool.self, forKey: .experimentalFeatures)
        groupChatsEnabled = try container.decode(Bool.self, forKey: .groupChatsEnabled)
        sendOnEnter = try container.decodeIfPresent(Bool.self, forKey: .sendOnEnter) ?? true
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        chatStyle = try container.decodeIfPresent(ChatStyle.self, forKey: .chatStyle) ?? .default
        imageGenerationEnabled = try container.decodeIfPresent(Bool.self, forKey: .imageGenerationEnabled) ?? false
    }

    init(
        activeAPI: APIType, activeModel: String, userName: String,
        activePersona: String?, activeCharacter: String?,
        defaultSystemPrompt: String, apiConfigurations: [String: APIConfigurationData],
        advancedMode: Bool, experimentalFeatures: Bool, groupChatsEnabled: Bool,
        sendOnEnter: Bool, theme: AppTheme = .system, hasCompletedOnboarding: Bool = false,
        chatStyle: ChatStyle = .default, imageGenerationEnabled: Bool = false
    ) {
        self.activeAPI = activeAPI
        self.activeModel = activeModel
        self.userName = userName
        self.activePersona = activePersona
        self.activeCharacter = activeCharacter
        self.defaultSystemPrompt = defaultSystemPrompt
        self.apiConfigurations = apiConfigurations
        self.advancedMode = advancedMode
        self.experimentalFeatures = experimentalFeatures
        self.groupChatsEnabled = groupChatsEnabled
        self.sendOnEnter = sendOnEnter
        self.theme = theme
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.chatStyle = chatStyle
        self.imageGenerationEnabled = imageGenerationEnabled
    }

    static let `default` = AppSettings(
        activeAPI: .openrouter,
        activeModel: "openai/gpt-4o",
        userName: "User",
        activePersona: nil,
        activeCharacter: nil,
        defaultSystemPrompt: "Write {{char}}'s next reply in a fictional chat between {{char}} and {{user}}. Write 1 reply only in internet RP style, italicize actions, and avoid quotation marks. Use markdown. Be proactive, creative, and drive the plot and conversation forward. Write at least 1 paragraph, up to 4. Always stay in character and avoid repetition.",
        apiConfigurations: [:],
        advancedMode: false,
        experimentalFeatures: false,
        groupChatsEnabled: false,
        sendOnEnter: true,
        theme: .system,
        hasCompletedOnboarding: false
    )
}

enum APIType: String, Codable, CaseIterable, Identifiable {
    case openai
    case claude
    case gemini
    case ollama
    case openrouter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .claude: return "Claude (Anthropic)"
        case .gemini: return "Google Gemini"
        case .ollama: return "Ollama (Local)"
        case .openrouter: return "OpenRouter"
        }
    }

    var defaultModels: [String] {
        switch self {
        case .openai: return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo", "o1", "o1-mini"]
        case .claude: return ["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5-20251001", "claude-3-5-sonnet-20241022"]
        case .gemini: return ["gemini-2.0-flash", "gemini-2.0-pro", "gemini-1.5-pro", "gemini-1.5-flash"]
        case .ollama: return ["llama3.1", "llama3", "mistral", "mixtral", "codellama", "phi3"]
        case .openrouter: return [
            // OpenAI
            "openai/gpt-4o", "openai/gpt-4o-mini", "openai/gpt-4-turbo", "openai/o1", "openai/o1-mini", "openai/o3-mini",
            // Anthropic
            "anthropic/claude-opus-4", "anthropic/claude-sonnet-4", "anthropic/claude-3.5-sonnet", "anthropic/claude-3-haiku",
            // Google
            "google/gemini-2.5-pro-preview", "google/gemini-2.5-flash-preview", "google/gemini-2.0-flash-001", "google/gemini-2.0-pro-exp", "google/gemini-pro-1.5", "google/gemini-flash-1.5",
            // Meta Llama
            "meta-llama/llama-4-maverick", "meta-llama/llama-4-scout", "meta-llama/llama-3.3-70b-instruct", "meta-llama/llama-3.1-405b-instruct", "meta-llama/llama-3.1-70b-instruct", "meta-llama/llama-3.1-8b-instruct",
            // Mistral
            "mistralai/mistral-large-2411", "mistralai/mistral-medium", "mistralai/mistral-small-3.1-24b-instruct", "mistralai/mixtral-8x22b-instruct", "mistralai/mixtral-8x7b-instruct",
            // DeepSeek
            "deepseek/deepseek-chat-v3-0324", "deepseek/deepseek-r1",
            // Qwen
            "qwen/qwen-2.5-72b-instruct", "qwen/qwen-2.5-coder-32b-instruct", "qwen/qwq-32b",
            // Cohere
            "cohere/command-r-plus", "cohere/command-r",
            // xAI
            "x-ai/grok-2-1212", "x-ai/grok-3-mini-beta",
            // Other
            "nousresearch/hermes-3-llama-3.1-405b", "microsoft/phi-4",
        ]
        }
    }

    var requiresAPIKey: Bool {
        self != .ollama
    }

    var keychainKey: String {
        "api_key_\(rawValue)"
    }
}

struct APIConfigurationData: Codable {
    var baseURL: String?
    var model: String
    var generationParams: GenerationParameters

    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case model
        case generationParams = "generation_params"
    }

    static func defaultConfig(for api: APIType) -> APIConfigurationData {
        APIConfigurationData(
            baseURL: api == .ollama ? "http://localhost:11434" : nil,
            model: api.defaultModels.first ?? "",
            generationParams: .default
        )
    }
}
