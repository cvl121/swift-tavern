import XCTest
@testable import SwiftTavern

// MARK: - ImageGenerationSettings Tests

final class ImageGenerationSettingsTests: XCTestCase {

    func testDefaultSettings() {
        let settings = ImageGenerationSettings.default
        XCTAssertFalse(settings.enabled)
        XCTAssertEqual(settings.provider, .openaiDalle)
        XCTAssertEqual(settings.model, "dall-e-3")
        XCTAssertNil(settings.baseURL)
        XCTAssertEqual(settings.imageSize, .square1024)
        XCTAssertEqual(settings.quality, .standard)
        XCTAssertEqual(settings.triggerMode, .manual)
        XCTAssertEqual(settings.messageInterval, 5)
        XCTAssertTrue(settings.useMainAPIForSceneSummary)
        XCTAssertFalse(settings.injectionPrompt.isEmpty)
        XCTAssertFalse(settings.scenePromptTemplate.isEmpty)
    }

    func testSettingsEncodingDecoding() throws {
        var settings = ImageGenerationSettings.default
        settings.enabled = true
        settings.provider = .stabilityAI
        settings.model = "stable-diffusion-xl"
        settings.imageSize = .landscape1792x1024
        settings.quality = .hd
        settings.triggerMode = .everyNMessages
        settings.messageInterval = 10

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ImageGenerationSettings.self, from: data)

        XCTAssertEqual(decoded.enabled, true)
        XCTAssertEqual(decoded.provider, .stabilityAI)
        XCTAssertEqual(decoded.model, "stable-diffusion-xl")
        XCTAssertEqual(decoded.imageSize, .landscape1792x1024)
        XCTAssertEqual(decoded.quality, .hd)
        XCTAssertEqual(decoded.triggerMode, .everyNMessages)
        XCTAssertEqual(decoded.messageInterval, 10)
    }

    func testAppSettingsBackwardsCompatibility() throws {
        // Settings JSON without imageGenerationSettings should decode with defaults
        let json = """
        {
            "active_api": "openrouter",
            "active_model": "openai/gpt-4o",
            "user_name": "User",
            "default_system_prompt": "test",
            "api_configurations": {},
            "advanced_mode": false,
            "experimental_features": false,
            "group_chats_enabled": false
        }
        """
        let data = json.data(using: .utf8)!
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.imageGenerationSettings.enabled, false)
        XCTAssertEqual(settings.imageGenerationSettings.provider, .openaiDalle)
    }

    func testAppSettingsWithImageGenSettings() throws {
        var appSettings = AppSettings.default
        appSettings.imageGenerationSettings.enabled = true
        appSettings.imageGenerationSettings.provider = .openrouter
        appSettings.imageGenerationSettings.model = "openai/dall-e-3"

        let data = try JSONEncoder().encode(appSettings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertTrue(decoded.imageGenerationSettings.enabled)
        XCTAssertEqual(decoded.imageGenerationSettings.provider, .openrouter)
        XCTAssertEqual(decoded.imageGenerationSettings.model, "openai/dall-e-3")
    }
}

// MARK: - ImageGenProvider Tests

final class ImageGenProviderTests: XCTestCase {

    func testProviderDisplayNames() {
        XCTAssertEqual(ImageGenProvider.openaiDalle.displayName, "OpenAI DALL-E")
        XCTAssertEqual(ImageGenProvider.stabilityAI.displayName, "Stability AI")
        XCTAssertEqual(ImageGenProvider.openrouter.displayName, "OpenRouter")
        XCTAssertEqual(ImageGenProvider.custom.displayName, "Custom")
    }

    func testProviderDefaultModels() {
        XCTAssertTrue(ImageGenProvider.openaiDalle.defaultModels.contains("dall-e-3"))
        XCTAssertTrue(ImageGenProvider.stabilityAI.defaultModels.count > 0)
        XCTAssertTrue(ImageGenProvider.openrouter.defaultModels.count > 0)
        XCTAssertTrue(ImageGenProvider.custom.defaultModels.isEmpty)
    }

    func testProviderAPIKeySettings() {
        XCTAssertEqual(ImageGenProvider.openaiDalle.apiKeySettingsKey, "image_gen_openai_dalle")
        XCTAssertEqual(ImageGenProvider.stabilityAI.apiKeySettingsKey, "image_gen_stability_ai")
    }

    func testProviderDefaultBaseURLs() {
        XCTAssertEqual(ImageGenProvider.openaiDalle.defaultBaseURL, "https://api.openai.com")
        XCTAssertEqual(ImageGenProvider.stabilityAI.defaultBaseURL, "https://api.stability.ai")
    }
}

// MARK: - ImageSize Tests

final class ImageSizeTests: XCTestCase {

    func testImageSizeDimensions() {
        XCTAssertEqual(ImageSize.square1024.width, 1024)
        XCTAssertEqual(ImageSize.square1024.height, 1024)
        XCTAssertEqual(ImageSize.landscape1792x1024.width, 1792)
        XCTAssertEqual(ImageSize.landscape1792x1024.height, 1024)
        XCTAssertEqual(ImageSize.portrait1024x1792.width, 1024)
        XCTAssertEqual(ImageSize.portrait1024x1792.height, 1792)
    }

    func testImageSizeRawValues() {
        XCTAssertEqual(ImageSize.square1024.rawValue, "1024x1024")
        XCTAssertEqual(ImageSize.landscape1792x1024.rawValue, "1792x1024")
    }
}

// MARK: - ChatMessage Image Fields Tests

final class ChatMessageImageTests: XCTestCase {

    func testMessageWithoutImage() {
        let msg = ChatMessage(name: "Bot", isUser: false, mes: "Hello")
        XCTAssertFalse(msg.hasImage)
        XCTAssertNil(msg.imageURL)
        XCTAssertNil(msg.imagePrompt)
    }

    func testMessageWithImage() {
        let msg = ChatMessage(
            name: "Bot",
            isUser: false,
            mes: "*A scene unfolds...*",
            imageURL: "Character/12345_abc.png",
            imagePrompt: "A dark forest at night"
        )
        XCTAssertTrue(msg.hasImage)
        XCTAssertEqual(msg.imageURL, "Character/12345_abc.png")
        XCTAssertEqual(msg.imagePrompt, "A dark forest at night")
    }

    func testImageFieldsEncodeDecode() throws {
        let original = ChatMessage(
            name: "Bot",
            isUser: false,
            mes: "Scene",
            imageURL: "test/image.png",
            imagePrompt: "A test prompt"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded.imageURL, "test/image.png")
        XCTAssertEqual(decoded.imagePrompt, "A test prompt")
        XCTAssertTrue(decoded.hasImage)
    }

    func testImageFieldsBackwardsCompatibility() throws {
        // Old message JSON without image fields should decode fine
        let json = """
        {
            "name": "Bot",
            "is_user": false,
            "send_date": "2024-01-01T00:00:00.000Z",
            "mes": "Hello"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertFalse(msg.hasImage)
        XCTAssertNil(msg.imageURL)
        XCTAssertNil(msg.imagePrompt)
    }
}

// MARK: - ScenePromptBuilder Tests

final class ScenePromptBuilderTests: XCTestCase {

    func testBuildMessagesStructure() {
        let character = CharacterData(
            name: "Alice",
            description: "A young woman with blue eyes and silver hair.",
            personality: "Kind and thoughtful"
        )

        let messages = [
            ChatMessage(name: "User", isUser: true, mes: "What do you see?"),
            ChatMessage(name: "Alice", isUser: false, mes: "*She looks around the garden.* I see flowers everywhere."),
        ]

        let result = ScenePromptBuilder.buildMessages(
            character: character,
            recentMessages: messages,
            userName: "User",
            template: ImageGenerationSettings.defaultScenePromptTemplate
        )

        // Should have: system prompt, 2 chat messages, final user prompt
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0].role, .system)
        XCTAssertEqual(result[1].role, .user)
        XCTAssertEqual(result[2].role, .assistant)
        XCTAssertEqual(result[3].role, .user)

        // System prompt should contain the character description
        XCTAssertTrue(result[0].content.contains("blue eyes"))
        XCTAssertTrue(result[0].content.contains("silver hair"))

        // Final prompt should request the scene description
        XCTAssertTrue(result[3].content.contains("scene"))
    }

    func testCharDescriptionSubstitution() {
        let character = CharacterData(name: "Bob", description: "A tall knight in shining armor")
        let result = ScenePromptBuilder.buildMessages(
            character: character,
            recentMessages: [],
            userName: "User",
            template: "Describe the scene. Character: {{char_description}}"
        )

        XCTAssertTrue(result[0].content.contains("tall knight in shining armor"))
    }

    func testTemplateVariableReplacement() {
        let character = CharacterData(name: "Luna", description: "An elf")
        let result = ScenePromptBuilder.buildMessages(
            character: character,
            recentMessages: [],
            userName: "Hero",
            template: "{{char}} is talking to {{user}}. Description: {{char_description}}"
        )

        XCTAssertTrue(result[0].content.contains("Luna"))
        XCTAssertTrue(result[0].content.contains("Hero"))
    }

    func testRecentMessagesLimit() {
        let character = CharacterData(name: "Bot", description: "A robot")
        var messages: [ChatMessage] = []
        for i in 0..<20 {
            messages.append(ChatMessage(name: i % 2 == 0 ? "User" : "Bot", isUser: i % 2 == 0, mes: "Message \(i)"))
        }

        let result = ScenePromptBuilder.buildMessages(
            character: character,
            recentMessages: messages,
            userName: "User",
            template: "Describe the scene."
        )

        // Should have system + last 8 messages + final user prompt = 10
        XCTAssertEqual(result.count, 10)
    }

    func testSystemMessagesExcluded() {
        let character = CharacterData(name: "Bot", description: "")
        let messages = [
            ChatMessage(name: "System", isUser: false, isSystem: true, mes: "System note"),
            ChatMessage(name: "User", isUser: true, mes: "Hello"),
            ChatMessage(name: "Bot", isUser: false, mes: "Hi there"),
        ]

        let result = ScenePromptBuilder.buildMessages(
            character: character,
            recentMessages: messages,
            userName: "User",
            template: "Describe the scene."
        )

        // System + 2 chat messages (system msg excluded) + final prompt = 4
        XCTAssertEqual(result.count, 4)
    }
}

// MARK: - ImageGenServiceFactory Tests

final class ImageGenServiceFactoryTests: XCTestCase {

    func testFactoryCreatesDalleService() {
        let service = ImageGenServiceFactory.create(for: .openaiDalle)
        XCTAssertTrue(service is DalleImageService)
    }

    func testFactoryCreatesStabilityService() {
        let service = ImageGenServiceFactory.create(for: .stabilityAI)
        XCTAssertTrue(service is StabilityImageService)
    }

    func testFactoryCreatesOpenRouterService() {
        let service = ImageGenServiceFactory.create(for: .openrouter)
        XCTAssertTrue(service is OpenRouterImageService)
    }

    func testFactoryCreatesCustomService() {
        let service = ImageGenServiceFactory.create(for: .custom)
        // Custom uses DalleImageService (DALL-E compatible format)
        XCTAssertTrue(service is DalleImageService)
    }
}

// MARK: - PromptBuilder Image Injection Tests

final class PromptBuilderImageInjectionTests: XCTestCase {

    func testBuildMessagesWithoutInjection() {
        let character = CharacterData(name: "Bot", description: "A bot")
        let messages = [ChatMessage(name: "User", isUser: true, mes: "Hello")]

        let result = PromptBuilder.buildMessages(
            character: character,
            chatHistory: messages,
            userName: "User"
        )

        // Should NOT contain any image generation instructions
        let allContent = result.map(\.content).joined()
        XCTAssertFalse(allContent.contains("GENERATE_IMAGE"))
    }

    func testBuildMessagesWithInjection() {
        let character = CharacterData(name: "Bot", description: "A bot")
        let messages = [ChatMessage(name: "User", isUser: true, mes: "Hello")]
        let injection = "[Image Gen] Include [GENERATE_IMAGE] when appropriate."

        let result = PromptBuilder.buildMessages(
            character: character,
            chatHistory: messages,
            userName: "User",
            imageInjectionPrompt: injection
        )

        // Last message should be the injection prompt
        let lastSystem = result.last { $0.role == .system }
        XCTAssertNotNil(lastSystem)
        XCTAssertTrue(lastSystem!.content.contains("GENERATE_IMAGE"))
    }

    func testEmptyInjectionPromptNotIncluded() {
        let character = CharacterData(name: "Bot", description: "A bot")
        let messages = [ChatMessage(name: "User", isUser: true, mes: "Hello")]

        let result = PromptBuilder.buildMessages(
            character: character,
            chatHistory: messages,
            userName: "User",
            imageInjectionPrompt: ""
        )

        // No extra system message for empty injection
        let systemMessages = result.filter { $0.role == .system }
        XCTAssertEqual(systemMessages.count, 1) // Only the main system prompt
    }
}

// MARK: - DataDirectoryManager Tests

final class DataDirectoryManagerImageTests: XCTestCase {

    func testGeneratedImagesDirectoryExists() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let manager = DataDirectoryManager(rootDirectory: tempDir)

        XCTAssertTrue(DataDirectoryManager.subdirectories.contains("generated_images"))
        XCTAssertEqual(
            manager.generatedImagesDirectory.lastPathComponent,
            "generated_images"
        )

        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Image Trigger Logic Tests

final class ImageTriggerTests: XCTestCase {

    func testGenerateImageTagDetection() {
        let text = "*The door creaked open.* [GENERATE_IMAGE]\nShe stepped inside."
        XCTAssertTrue(text.contains("[GENERATE_IMAGE]"))

        let stripped = text.replacingOccurrences(of: "[GENERATE_IMAGE]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(stripped.contains("[GENERATE_IMAGE]"))
        XCTAssertTrue(stripped.contains("door creaked open"))
        XCTAssertTrue(stripped.contains("stepped inside"))
    }

    func testTriggerModeEnumValues() {
        XCTAssertEqual(ImageTriggerMode.manual.displayName, "Manual Only")
        XCTAssertEqual(ImageTriggerMode.everyNMessages.displayName, "Every N Messages")
        XCTAssertEqual(ImageTriggerMode.injectedPrompt.displayName, "LLM-Triggered")
    }

    func testTriggerModeEncodeDecode() throws {
        for mode in ImageTriggerMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(ImageTriggerMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }
}

// MARK: - AppState Image Gen Accessors Tests

final class AppStateImageGenTests: XCTestCase {

    func testImageGenServiceCreation() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)

        let service = appState.imageGenService()
        XCTAssertTrue(service is DalleImageService) // Default provider is DALL-E

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testImageGenAPIKeyRetrieval() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)

        // No key set initially
        XCTAssertTrue(appState.imageGenAPIKey().isEmpty)

        // Set a key
        appState.settings.apiKeys["image_gen_openai_dalle"] = "test-key-123"
        XCTAssertEqual(appState.imageGenAPIKey(), "test-key-123")

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testGeneratedImagesDirectory() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTavernTests-\(UUID().uuidString)")
        let appState = AppState(rootDirectory: tempDir)

        let dir = appState.generatedImagesDirectory(for: "TestChar")
        XCTAssertTrue(dir.path.contains("generated_images"))
        XCTAssertTrue(dir.path.contains("TestChar"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))

        try? FileManager.default.removeItem(at: tempDir)
    }
}
