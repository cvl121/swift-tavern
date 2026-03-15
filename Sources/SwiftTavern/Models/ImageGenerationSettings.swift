import Foundation

/// Image generation provider options
enum ImageGenProvider: String, Codable, CaseIterable, Identifiable {
    case openaiDalle = "openai_dalle"
    case stabilityAI = "stability_ai"
    case openrouter = "openrouter"
    case novelai = "novelai"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openaiDalle: return "OpenAI DALL-E"
        case .stabilityAI: return "Stability AI"
        case .openrouter: return "OpenRouter"
        case .novelai: return "NovelAI"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .openaiDalle: return "Generate images with DALL-E 3 or gpt-image-1. Requires an OpenAI API key."
        case .stabilityAI: return "Generate images with Stable Diffusion models. Requires a Stability AI key."
        case .openrouter: return "Use image models through OpenRouter. Uses your OpenRouter API key."
        case .novelai: return "Generate anime-style images with NovelAI Diffusion. Uses your NovelAI API key."
        case .custom: return "Connect to a custom image generation API that uses the OpenAI images format."
        }
    }

    var defaultModels: [String] {
        switch self {
        case .openaiDalle: return ["gpt-image-1.5", "gpt-image-1", "gpt-image-1-mini", "dall-e-3", "dall-e-2"]
        case .stabilityAI: return ["sd3.5-large", "sd3.5-large-turbo", "sd3.5-medium"]
        case .openrouter: return ["openai/gpt-5-image-mini", "openai/gpt-5-image", "google/gemini-2.5-flash-image", "google/gemini-3.1-flash-image-preview", "google/gemini-3-pro-image-preview"]
        case .novelai: return ["nai-diffusion-4-5-curated", "nai-diffusion-4-5-full", "nai-diffusion-4-curated-preview", "nai-diffusion-4-full", "nai-diffusion-3"]
        case .custom: return []
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openaiDalle: return "https://api.openai.com"
        case .stabilityAI: return "https://api.stability.ai"
        case .openrouter: return "https://openrouter.ai/api"
        case .novelai: return "https://image.novelai.net"
        case .custom: return ""
        }
    }

    var apiKeySettingsKey: String {
        "image_gen_\(rawValue)"
    }

    /// Whether this provider supports a negative prompt field
    var supportsNegativePrompt: Bool {
        switch self {
        case .novelai, .stabilityAI: return true
        default: return false
        }
    }

    /// Whether this provider supports using a reference image (img2img)
    var supportsReferenceImage: Bool {
        switch self {
        case .novelai, .openrouter: return true
        default: return false
        }
    }

    /// Prompt format guidance for the user
    var promptHint: String {
        switch self {
        case .novelai: return "NovelAI works best with comma-separated danbooru-style tags.\nExample: 1girl, long hair, blue eyes, forest, sunlight, detailed background, masterpiece"
        case .openaiDalle: return "Describe the scene in natural language. Be specific about composition, style, lighting, and mood."
        case .openrouter: return "Describe the scene in natural language. The prompt is sent to the selected image model via chat."
        case .stabilityAI: return "Use descriptive visual language. Supports negative prompts to exclude unwanted elements."
        case .custom: return "Enter your image prompt below."
        }
    }

    /// Placeholder text for the negative prompt field
    var negativePromptHint: String {
        switch self {
        case .novelai: return "lowres, bad anatomy, bad hands, text, error, worst quality, low quality, jpeg artifacts, watermark, blurry"
        case .stabilityAI: return "blurry, low quality, distorted, watermark, text"
        default: return ""
        }
    }

    /// Whether this provider can share an API key with a text provider
    var sharedTextProvider: APIType? {
        switch self {
        case .openaiDalle: return .openai
        case .openrouter: return .openrouter
        case .novelai: return .novelai
        default: return nil
        }
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

    var description: String {
        switch self {
        case .manual: return "Click the camera button in the chat to generate an image of the current scene."
        case .everyNMessages: return "Automatically generate an image after a set number of messages."
        case .injectedPrompt: return "The AI will decide when to generate images based on the story."
        }
    }
}

/// Image output dimensions
enum ImageSize: String, Codable, CaseIterable, Identifiable {
    case square1024 = "1024x1024"
    case landscape1792x1024 = "1792x1024"
    case portrait1024x1792 = "1024x1792"
    case square512 = "512x512"
    case square768 = "768x768"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .square1024: return "Square (1024x1024)"
        case .landscape1792x1024: return "Landscape (1792x1024)"
        case .portrait1024x1792: return "Portrait (1024x1792)"
        case .square512: return "Small Square (512x512)"
        case .square768: return "Medium Square (768x768)"
        }
    }

    var width: Int {
        switch self {
        case .square1024: return 1024
        case .landscape1792x1024: return 1792
        case .portrait1024x1792: return 1024
        case .square512: return 512
        case .square768: return 768
        }
    }

    var height: Int {
        switch self {
        case .square1024: return 1024
        case .landscape1792x1024: return 1024
        case .portrait1024x1792: return 1792
        case .square512: return 512
        case .square768: return 768
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

/// Controls how large images appear in the chat conversation
enum ImageDisplaySize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case full

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .full: return "Full Width"
        }
    }

    var maxWidth: CGFloat {
        switch self {
        case .small: return 200
        case .medium: return 350
        case .large: return 500
        case .full: return .infinity
        }
    }

    var maxHeight: CGFloat {
        switch self {
        case .small: return 200
        case .medium: return 350
        case .large: return 500
        case .full: return 600
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
    /// Whether to use the same API key as the text provider (when providers overlap)
    var useSharedAPIKey: Bool
    /// How large images appear in the conversation
    var displaySize: ImageDisplaySize
    /// Whether to use the character's avatar as a reference image (img2img)
    var useReferenceImage: Bool
    /// How strongly the reference image influences the output (0.0 = ignore, 1.0 = very close)
    var referenceImageStrength: Double

    enum CodingKeys: String, CodingKey {
        case enabled, provider, model, quality
        case baseURL = "base_url"
        case imageSize = "image_size"
        case triggerMode = "trigger_mode"
        case messageInterval = "message_interval"
        case injectionPrompt = "injection_prompt"
        case scenePromptTemplate = "scene_prompt_template"
        case useMainAPIForSceneSummary = "use_main_api_for_scene_summary"
        case useSharedAPIKey = "use_shared_api_key"
        case displaySize = "display_size"
        case useReferenceImage = "use_reference_image"
        case referenceImageStrength = "reference_image_strength"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        provider = try container.decodeIfPresent(ImageGenProvider.self, forKey: .provider) ?? .openaiDalle
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? "dall-e-3"
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL)
        imageSize = try container.decodeIfPresent(ImageSize.self, forKey: .imageSize) ?? .square1024
        quality = try container.decodeIfPresent(ImageQuality.self, forKey: .quality) ?? .standard
        triggerMode = try container.decodeIfPresent(ImageTriggerMode.self, forKey: .triggerMode) ?? .manual
        messageInterval = try container.decodeIfPresent(Int.self, forKey: .messageInterval) ?? 5
        injectionPrompt = try container.decodeIfPresent(String.self, forKey: .injectionPrompt) ?? Self.defaultInjectionPrompt
        scenePromptTemplate = try container.decodeIfPresent(String.self, forKey: .scenePromptTemplate) ?? Self.defaultScenePromptTemplate
        useMainAPIForSceneSummary = try container.decodeIfPresent(Bool.self, forKey: .useMainAPIForSceneSummary) ?? true
        useSharedAPIKey = try container.decodeIfPresent(Bool.self, forKey: .useSharedAPIKey) ?? true
        displaySize = try container.decodeIfPresent(ImageDisplaySize.self, forKey: .displaySize) ?? .medium
        useReferenceImage = try container.decodeIfPresent(Bool.self, forKey: .useReferenceImage) ?? false
        referenceImageStrength = try container.decodeIfPresent(Double.self, forKey: .referenceImageStrength) ?? 0.6
    }

    init(
        enabled: Bool = false,
        provider: ImageGenProvider = .openaiDalle,
        model: String = "dall-e-3",
        baseURL: String? = nil,
        imageSize: ImageSize = .square1024,
        quality: ImageQuality = .standard,
        triggerMode: ImageTriggerMode = .manual,
        messageInterval: Int = 5,
        injectionPrompt: String = ImageGenerationSettings.defaultInjectionPrompt,
        scenePromptTemplate: String = ImageGenerationSettings.defaultScenePromptTemplate,
        useMainAPIForSceneSummary: Bool = true,
        useSharedAPIKey: Bool = true,
        displaySize: ImageDisplaySize = .medium,
        useReferenceImage: Bool = false,
        referenceImageStrength: Double = 0.6
    ) {
        self.enabled = enabled
        self.provider = provider
        self.model = model
        self.baseURL = baseURL
        self.imageSize = imageSize
        self.quality = quality
        self.triggerMode = triggerMode
        self.messageInterval = messageInterval
        self.injectionPrompt = injectionPrompt
        self.scenePromptTemplate = scenePromptTemplate
        self.useMainAPIForSceneSummary = useMainAPIForSceneSummary
        self.useSharedAPIKey = useSharedAPIKey
        self.displaySize = displaySize
        self.useReferenceImage = useReferenceImage
        self.referenceImageStrength = referenceImageStrength
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

    static let `default` = ImageGenerationSettings()
}
