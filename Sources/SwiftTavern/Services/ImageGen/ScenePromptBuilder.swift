import Foundation

/// Builds an LLM prompt to distill the current scene into an image generation prompt
enum ScenePromptBuilder {
    /// Build messages for scene-to-prompt translation
    /// - Parameters:
    ///   - character: The character data (for description reference)
    ///   - recentMessages: The last N messages from the chat
    ///   - userName: The user's display name
    ///   - template: The scene prompt template from settings
    /// - Returns: Messages to send to the LLM for prompt distillation
    static func buildMessages(
        character: CharacterData,
        recentMessages: [ChatMessage],
        userName: String,
        template: String
    ) -> [LLMMessage] {
        var messages: [LLMMessage] = []

        // System instruction with character description injected
        let systemPrompt = template
            .replacingOccurrences(of: "{{char_description}}", with: character.description)
            .replacingTemplateVars(charName: character.name, userName: userName)

        messages.append(LLMMessage(role: .system, content: systemPrompt))

        // Include recent conversation as context
        let contextMessages = Array(recentMessages.suffix(8))
        for msg in contextMessages where !msg.isSystem {
            let role: MessageRole = msg.isUser ? .user : .assistant
            let content = msg.mes.replacingTemplateVars(charName: character.name, userName: userName)
            if !content.isEmpty {
                messages.append(LLMMessage(role: role, content: content))
            }
        }

        // Final user prompt requesting the image description
        messages.append(LLMMessage(
            role: .user,
            content: "Describe the current scene as a concise image generation prompt."
        ))

        return messages
    }
}
