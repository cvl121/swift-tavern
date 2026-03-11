import Foundation

/// Assembles character card data, world info, and chat history into an LLM messages array
enum PromptBuilder {
    /// Build the full message array for an LLM API call
    static func buildMessages(
        character: CharacterData,
        chatHistory: [ChatMessage],
        userName: String,
        systemPrompt: String? = nil,
        worldInfoEntries: [WorldInfoEntry] = [],
        persona: Persona? = nil,
        imageInjectionPrompt: String? = nil
    ) -> [LLMMessage] {
        var messages: [LLMMessage] = []

        // 1. System prompt
        let sysPrompt = (systemPrompt ?? character.systemPrompt)
            .replacingTemplateVars(charName: character.name, userName: userName)

        var systemContent = sysPrompt.isEmpty ? "You are \(character.name)." : sysPrompt

        // 2. Character description
        let description = character.description
            .replacingTemplateVars(charName: character.name, userName: userName)
        if !description.isEmpty {
            systemContent += "\n\n\(character.name)'s description: \(description)"
        }

        // 3. Personality
        let personality = character.personality
            .replacingTemplateVars(charName: character.name, userName: userName)
        if !personality.isEmpty {
            systemContent += "\n\(character.name)'s personality: \(personality)"
        }

        // 4. Scenario
        let scenario = character.scenario
            .replacingTemplateVars(charName: character.name, userName: userName)
        if !scenario.isEmpty {
            systemContent += "\nScenario: \(scenario)"
        }

        // 5. Persona description
        if let persona = persona, !persona.description.isEmpty {
            systemContent += "\n\n\(userName)'s description: \(persona.description)"
        }

        // 6. Character Book entries (embedded world info)
        if let charBook = character.characterBook {
            let bookEntries = charBook.entries
            let recentTextForBook = chatHistory.suffix(charBook.scanDepth ?? 10).map(\.mes).joined(separator: " ")

            for entry in bookEntries.sorted(by: { $0.insertionOrder < $1.insertionOrder }) {
                guard entry.enabled else { continue }
                let entryContent = entry.content.replacingTemplateVars(charName: character.name, userName: userName)
                if entry.constant {
                    systemContent += "\n\n\(entryContent)"
                } else if entry.keys.contains(where: { key in
                    let searchText = (entry.caseSensitive ?? false) ? recentTextForBook : recentTextForBook.lowercased()
                    let searchKey = (entry.caseSensitive ?? false) ? key : key.lowercased()
                    return searchText.contains(searchKey)
                }) {
                    systemContent += "\n\n\(entryContent)"
                }
            }
        }

        // 7. World Info - constant entries
        let constantEntries = worldInfoEntries.filter { $0.constant && $0.enabled }
        for entry in constantEntries.sorted(by: { $0.insertionOrder < $1.insertionOrder }) {
            let entryContent = entry.content.replacingTemplateVars(charName: character.name, userName: userName)
            systemContent += "\n\n\(entryContent)"
        }

        // 8. World Info - keyword-triggered entries
        let recentText = chatHistory.suffix(10).map(\.mes).joined(separator: " ")
        let triggeredEntries = worldInfoEntries.filter { entry in
            !entry.constant && entry.enabled && entry.keys.contains { key in
                let searchText = entry.caseSensitive ? recentText : recentText.lowercased()
                let searchKey = entry.caseSensitive ? key : key.lowercased()
                return searchText.contains(searchKey)
            }
        }
        for entry in triggeredEntries.sorted(by: { $0.insertionOrder < $1.insertionOrder }) {
            let entryContent = entry.content.replacingTemplateVars(charName: character.name, userName: userName)
            systemContent += "\n\n\(entryContent)"
        }

        messages.append(LLMMessage(role: .system, content: systemContent))

        // 9. Example messages (as few-shot)
        let mesExample = character.mesExample
            .replacingTemplateVars(charName: character.name, userName: userName)
        if !mesExample.isEmpty {
            let exampleMessages = parseExampleMessages(mesExample, characterName: character.name, userName: userName)
            messages.append(contentsOf: exampleMessages)
        }

        // 10. Post-history instructions
        let postInstructions = character.postHistoryInstructions
            .replacingTemplateVars(charName: character.name, userName: userName)

        // 11. Chat history (skip system messages — they are metadata, not conversation)
        for message in chatHistory where !message.isSystem {
            let role: MessageRole = message.isUser ? .user : .assistant
            let content = message.mes.replacingTemplateVars(charName: character.name, userName: userName)
            if !content.isEmpty {
                messages.append(LLMMessage(role: role, content: content))
            }
        }

        // 12. Post-history instructions (appended as system message after history)
        if !postInstructions.isEmpty {
            messages.append(LLMMessage(role: .system, content: postInstructions))
        }

        // 13. Image generation injection prompt (when LLM-triggered mode is active)
        if let imageInjectionPrompt, !imageInjectionPrompt.isEmpty {
            messages.append(LLMMessage(role: .system, content: imageInjectionPrompt))
        }

        return messages
    }

    /// Parse SillyTavern-format example messages into LLMMessages
    static func parseExampleMessages(
        _ example: String,
        characterName: String,
        userName: String
    ) -> [LLMMessage] {
        var messages: [LLMMessage] = []

        let lines = example
            .replacingOccurrences(of: "<START>", with: "")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            let userPrefixes = ["\(userName):", "{{user}}:"]
            let charPrefixes = ["\(characterName):", "{{char}}:"]

            if let prefix = userPrefixes.first(where: { line.hasPrefix($0) }) {
                let content = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                messages.append(LLMMessage(role: .user, content: content))
            } else if let prefix = charPrefixes.first(where: { line.hasPrefix($0) }) {
                let content = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                messages.append(LLMMessage(role: .assistant, content: content))
            }
        }

        return messages
    }
}
