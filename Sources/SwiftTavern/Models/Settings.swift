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
    var showChatButtonLabels: Bool
    var showIndividualConversations: Bool
    var developerMode: Bool
    /// Maps character filename → active chat filename
    var activeChatPerCharacter: [String: String]
    /// Maps APIType.rawValue → API key
    var apiKeys: [String: String]
    /// Global world lore book name (used when character has no specific world lore)
    var globalWorldLore: String?
    /// Maximum number of messages to display in chat (0 = unlimited)
    var chatDisplayLimit: Int
    /// Maximum character length per message to display (0 = unlimited)
    var chatMessageLengthLimit: Int
    /// Sidebar width preference
    var sidebarWidth: Double
    /// Whether sidebar is visible
    var sidebarVisible: Bool
    /// Chat input field height
    var chatInputHeight: Double
    /// App-wide UI font size multiplier (default 1.0 = 100%)
    var uiScale: Double

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
        case showChatButtonLabels = "show_chat_button_labels"
        case showIndividualConversations = "show_individual_conversations"
        case developerMode = "developer_mode"
        case activeChatPerCharacter = "active_chat_per_character"
        case apiKeys = "api_keys"
        case globalWorldLore = "global_world_lore"
        case chatDisplayLimit = "chat_display_limit"
        case chatMessageLengthLimit = "chat_message_length_limit"
        case sidebarWidth = "sidebar_width"
        case sidebarVisible = "sidebar_visible"
        case chatInputHeight = "chat_input_height"
        case uiScale = "ui_scale"
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
        showChatButtonLabels = try container.decodeIfPresent(Bool.self, forKey: .showChatButtonLabels) ?? false
        showIndividualConversations = try container.decodeIfPresent(Bool.self, forKey: .showIndividualConversations) ?? false
        developerMode = try container.decodeIfPresent(Bool.self, forKey: .developerMode) ?? false
        activeChatPerCharacter = try container.decodeIfPresent([String: String].self, forKey: .activeChatPerCharacter) ?? [:]
        apiKeys = try container.decodeIfPresent([String: String].self, forKey: .apiKeys) ?? [:]
        globalWorldLore = try container.decodeIfPresent(String.self, forKey: .globalWorldLore)
        chatDisplayLimit = try container.decodeIfPresent(Int.self, forKey: .chatDisplayLimit) ?? 0
        chatMessageLengthLimit = try container.decodeIfPresent(Int.self, forKey: .chatMessageLengthLimit) ?? 0
        sidebarWidth = try container.decodeIfPresent(Double.self, forKey: .sidebarWidth) ?? 250
        sidebarVisible = try container.decodeIfPresent(Bool.self, forKey: .sidebarVisible) ?? true
        chatInputHeight = try container.decodeIfPresent(Double.self, forKey: .chatInputHeight) ?? 32
        uiScale = try container.decodeIfPresent(Double.self, forKey: .uiScale) ?? 1.0
    }

    init(
        activeAPI: APIType, activeModel: String, userName: String,
        activePersona: String?, activeCharacter: String?,
        defaultSystemPrompt: String, apiConfigurations: [String: APIConfigurationData],
        advancedMode: Bool, experimentalFeatures: Bool, groupChatsEnabled: Bool,
        sendOnEnter: Bool, theme: AppTheme = .system, hasCompletedOnboarding: Bool = false,
        chatStyle: ChatStyle = .default, imageGenerationEnabled: Bool = false,
        showChatButtonLabels: Bool = false, showIndividualConversations: Bool = false,
        developerMode: Bool = false, activeChatPerCharacter: [String: String] = [:],
        apiKeys: [String: String] = [:],
        globalWorldLore: String? = nil,
        chatDisplayLimit: Int = 0,
        chatMessageLengthLimit: Int = 0,
        sidebarWidth: Double = 250,
        sidebarVisible: Bool = true,
        chatInputHeight: Double = 32,
        uiScale: Double = 1.0
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
        self.showChatButtonLabels = showChatButtonLabels
        self.showIndividualConversations = showIndividualConversations
        self.developerMode = developerMode
        self.activeChatPerCharacter = activeChatPerCharacter
        self.apiKeys = apiKeys
        self.globalWorldLore = globalWorldLore
        self.chatDisplayLimit = chatDisplayLimit
        self.chatMessageLengthLimit = chatMessageLengthLimit
        self.sidebarWidth = sidebarWidth
        self.sidebarVisible = sidebarVisible
        self.chatInputHeight = chatInputHeight
        self.uiScale = uiScale
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
    case novelai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .claude: return "Claude (Anthropic)"
        case .gemini: return "Google Gemini"
        case .ollama: return "Ollama (Local)"
        case .openrouter: return "OpenRouter"
        case .novelai: return "NovelAI"
        }
    }

    var defaultModels: [String] {
        switch self {
        case .openai: return [
            // GPT-4o family
            "gpt-4o", "gpt-4o-2024-11-20", "gpt-4o-2024-08-06", "gpt-4o-2024-05-13",
            "gpt-4o-mini", "gpt-4o-mini-2024-07-18",
            "gpt-4o-audio-preview", "gpt-4o-audio-preview-2024-12-17",
            // GPT-4.1 family
            "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano",
            // o-series reasoning
            "o1", "o1-2024-12-17", "o1-mini", "o1-mini-2024-09-12", "o1-preview", "o1-preview-2024-09-12",
            "o3", "o3-mini", "o3-mini-2025-01-31", "o4-mini",
            // GPT-4
            "gpt-4-turbo", "gpt-4-turbo-2024-04-09", "gpt-4-turbo-preview", "gpt-4-0125-preview", "gpt-4-1106-preview",
            "gpt-4", "gpt-4-0613",
            // GPT-3.5
            "gpt-3.5-turbo", "gpt-3.5-turbo-0125", "gpt-3.5-turbo-1106",
            // Chatgpt
            "chatgpt-4o-latest",
        ]
        case .claude: return [
            // Claude 4 family
            "claude-opus-4-6", "claude-sonnet-4-6",
            // Claude 3.5 family
            "claude-3-5-sonnet-20241022", "claude-3-5-sonnet-20240620", "claude-3-5-haiku-20241022",
            // Claude 3 family
            "claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-haiku-20240307",
            // Claude 4.5 / Haiku
            "claude-haiku-4-5-20251001",
        ]
        case .gemini: return [
            // Gemini 2.5
            "gemini-2.5-pro-preview-06-05", "gemini-2.5-flash-preview-05-20",
            // Gemini 2.0
            "gemini-2.0-flash", "gemini-2.0-flash-001", "gemini-2.0-flash-lite", "gemini-2.0-flash-lite-001",
            "gemini-2.0-flash-thinking-exp", "gemini-2.0-pro-exp",
            // Gemini 1.5
            "gemini-1.5-pro", "gemini-1.5-pro-001", "gemini-1.5-pro-002",
            "gemini-1.5-flash", "gemini-1.5-flash-001", "gemini-1.5-flash-002",
            "gemini-1.5-flash-8b", "gemini-1.5-flash-8b-001",
        ]
        case .ollama: return [
            // Meta Llama
            "llama3.3", "llama3.2", "llama3.1", "llama3.1:70b", "llama3.1:405b", "llama3",
            // Mistral
            "mistral", "mistral-nemo", "mistral-large", "mistral-small", "mixtral", "mixtral:8x22b",
            // Qwen
            "qwen2.5", "qwen2.5:72b", "qwen2.5-coder", "qwen2.5-coder:32b", "qwq",
            // Google
            "gemma2", "gemma2:27b",
            // DeepSeek
            "deepseek-r1", "deepseek-r1:70b", "deepseek-v2.5",
            // Microsoft
            "phi4", "phi3", "phi3:medium",
            // Coding
            "codellama", "codellama:70b", "starcoder2",
            // Other
            "command-r", "command-r-plus", "solar", "nous-hermes2", "dolphin-mixtral", "vicuna", "neural-chat",
        ]
        case .novelai: return [
            "kayra-v2", "kayra-v1", "clio-v1", "llama-3-erato-v1",
        ]
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

    var defaultBaseURL: String? {
        switch self {
        case .novelai: return "https://text.novelai.net"
        default: return nil
        }
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
