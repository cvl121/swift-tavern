import Foundation

/// Image generation provider options
enum ImageGenProvider: String, Codable, CaseIterable, Identifiable {
    case openaiDalle = "openai_dalle"
    case stabilityAI = "stability_ai"
    case openrouter = "openrouter"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openaiDalle: return "OpenAI DALL-E"
        case .stabilityAI: return "Stability AI"
        case .openrouter: return "OpenRouter"
        case .custom: return "Custom"
        }
    }

    var defaultModels: [String] {
        switch self {
        case .openaiDalle: return ["dall-e-3", "dall-e-2", "gpt-image-1"]
        case .stabilityAI: return ["stable-diffusion-xl-1024-v1-0", "stable-diffusion-v1-6", "stable-image-ultra"]
        case .openrouter: return ["openai/dall-e-3"]
        case .custom: return []
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openaiDalle: return "https://api.openai.com"
        case .stabilityAI: return "https://api.stability.ai"
        case .openrouter: return "https://openrouter.ai/api"
        case .custom: return ""
        }
    }

    var apiKeySettingsKey: String {
        "image_gen_\(rawValue)"
    }
}

/// How image generation is triggered
enum ImageTriggerMode: String, Codable, CaseIterable, Identifiable {
    case manual
    case everyNMessages = "every_n_messages"
    case injectedPrompt = "injected_prompt"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: return "Manual Only"
        case .everyNMessages: return "Every N Messages"
        case .injectedPrompt: return "LLM-Triggered"
        }
    }
}

/// Image output dimensions
enum ImageSize: String, Codable, CaseIterable, Identifiable {
    case square1024 = "1024x1024"
    case landscape1792x1024 = "1792x1024"
    case portrait1024x1792 = "1024x1792"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .square1024: return "Square (1024x1024)"
        case .landscape1792x1024: return "Landscape (1792x1024)"
        case .portrait1024x1792: return "Portrait (1024x1792)"
        }
    }

    var width: Int {
        switch self {
        case .square1024: return 1024
        case .landscape1792x1024: return 1792
        case .portrait1024x1792: return 1024
        }
    }

    var height: Int {
        switch self {
        case .square1024: return 1024
        case .landscape1792x1024: return 1024
        case .portrait1024x1792: return 1792
        }
    }
}

/// Image quality option (primarily for DALL-E)
enum ImageQuality: String, Codable, CaseIterable, Identifiable {
    case standard
    case hd

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .hd: return "HD"
        }
    }
}

/// Settings for image generation feature
struct ImageGenerationSettings: Codable, Equatable {
    var enabled: Bool
    var provider: ImageGenProvider
    var model: String
    var baseURL: String?
    var imageSize: ImageSize
    var quality: ImageQuality
    var triggerMode: ImageTriggerMode
    var messageInterval: Int
    var injectionPrompt: String
    var scenePromptTemplate: String
    var useMainAPIForSceneSummary: Bool

    enum CodingKeys: String, CodingKey {
        case enabled, provider, model, quality
        case baseURL = "base_url"
        case imageSize = "image_size"
        case triggerMode = "trigger_mode"
        case messageInterval = "message_interval"
        case injectionPrompt = "injection_prompt"
        case scenePromptTemplate = "scene_prompt_template"
        case useMainAPIForSceneSummary = "use_main_api_for_scene_summary"
    }

    static let defaultInjectionPrompt = """
        [Image Generation Instructions]
        You have the ability to request scene illustrations during the conversation.
        When a visually significant moment occurs — such as arriving at a new location,
        a dramatic change in scenery, a character's appearance changing, or an emotionally
        impactful scene — include the exact tag [GENERATE_IMAGE] on its own line within
        your response.

        Guidelines for when to use [GENERATE_IMAGE]:
        - When the scene transitions to a new environment or location
        - When a character's appearance or outfit changes significantly
        - During dramatic, climactic, or emotionally charged moments
        - When the user explicitly asks to see something
        - Do NOT use it for mundane conversation or minor actions
        - Use it at most once per response
        - Place it at the end of the paragraph describing the visual scene
        """

    static let defaultScenePromptTemplate = """
        Based on the recent conversation, describe the current scene as a visual image \
        prompt. Focus on:
        - The physical environment/setting
        - Character appearances (clothing, expression, posture)
        - Lighting, colors, and mood
        - Composition and perspective

        Character appearance reference: {{char_description}}

        Output ONLY a concise image generation prompt (2-4 sentences). Do not include \
        dialogue, narration, or any non-visual elements. Use descriptive, visual language \
        suitable for an AI image generator.
        """

    static let `default` = ImageGenerationSettings(
        enabled: false,
        provider: .openaiDalle,
        model: "dall-e-3",
        baseURL: nil,
        imageSize: .square1024,
        quality: .standard,
        triggerMode: .manual,
        messageInterval: 5,
        injectionPrompt: defaultInjectionPrompt,
        scenePromptTemplate: defaultScenePromptTemplate,
        useMainAPIForSceneSummary: true
    )
}
