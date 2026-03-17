import Foundation

/// Assembles character card data, world info, and chat history into an LLM messages array
enum PromptBuilder {

    // MARK: - Keyword Scan Cache

    /// Cached result of a keyword scan against recent chat text
    private struct KeywordScanResult {
        let matchedEntryIndices: Set<Int>
        let contentHash: Int
    }

    /// Cache for character book keyword scan results, keyed by a hash of the scan text
    private static var charBookScanCache: KeywordScanResult?
    /// Cache for world info keyword scan results, keyed by a hash of the scan text
    private static var worldInfoScanCache: KeywordScanResult?

    /// Compute a simple hash for an array of entry keys + the search text to detect changes
    private static func keywordScanHash(text: String, entryKeys: [[String]]) -> Int {
        var hasher = Hasher()
        hasher.combine(text)
        for keys in entryKeys {
            for key in keys {
                hasher.combine(key)
            }
        }
        return hasher.finalize()
    }

    /// Scan entries for keyword matches against recent text, using cache when possible.
    /// Returns the set of entry indices (into the provided array) that matched.
    private static func scanKeywordMatches(
        entries: [(index: Int, keys: [String], caseSensitive: Bool)],
        recentText: String,
        cache: inout KeywordScanResult?
    ) -> Set<Int> {
        let entryKeys = entries.map(\.keys)
        let hash = keywordScanHash(text: recentText, entryKeys: entryKeys)

        if let cached = cache, cached.contentHash == hash {
            return cached.matchedEntryIndices
        }

        var matched = Set<Int>()
        for entry in entries {
            let searchText = entry.caseSensitive ? recentText : recentText.lowercased()
            for key in entry.keys {
                let searchKey = entry.caseSensitive ? key : key.lowercased()
                if searchText.contains(searchKey) {
                    matched.insert(entry.index)
                    break
                }
            }
        }

        cache = KeywordScanResult(matchedEntryIndices: matched, contentHash: hash)
        return matched
    }

    /// Build the full message array for an LLM API call
    static func buildMessages(
        character: CharacterData,
        chatHistory: [ChatMessage],
        userName: String,
        systemPrompt: String? = nil,
        worldInfoEntries: [WorldInfoEntry] = [],
        persona: Persona? = nil,
        imageInjectionPrompt: String? = nil,
        reminderPrompt: String? = nil
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

        // 6. Character Book entries (embedded world info) — with cached keyword scanning
        if let charBook = character.characterBook {
            let bookEntries = charBook.entries.sorted(by: { $0.insertionOrder < $1.insertionOrder })
            let recentTextForBook = chatHistory.suffix(charBook.scanDepth ?? 10).map(\.mes).joined(separator: " ")

            // Collect non-constant, enabled entries for keyword scanning
            var keywordEntries: [(index: Int, keys: [String], caseSensitive: Bool)] = []
            for (i, entry) in bookEntries.enumerated() {
                guard entry.enabled && !entry.constant else { continue }
                keywordEntries.append((index: i, keys: entry.keys, caseSensitive: entry.caseSensitive ?? false))
            }

            let matchedIndices = scanKeywordMatches(
                entries: keywordEntries,
                recentText: recentTextForBook,
                cache: &charBookScanCache
            )

            for (i, entry) in bookEntries.enumerated() {
                guard entry.enabled else { continue }
                let entryContent = entry.content.replacingTemplateVars(charName: character.name, userName: userName)
                if entry.constant || matchedIndices.contains(i) {
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

        // 8. World Info - keyword-triggered entries — with cached keyword scanning
        let recentText = chatHistory.suffix(10).map(\.mes).joined(separator: " ")
        let nonConstantEntries = worldInfoEntries.enumerated().filter { !$0.element.constant && $0.element.enabled }
        let keywordEntries = nonConstantEntries.map { (index: $0.offset, keys: $0.element.keys, caseSensitive: $0.element.caseSensitive) }

        let matchedWorldIndices = scanKeywordMatches(
            entries: keywordEntries,
            recentText: recentText,
            cache: &worldInfoScanCache
        )

        let triggeredEntries = nonConstantEntries.filter { matchedWorldIndices.contains($0.offset) }.map(\.element)
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

        // 12. Reminder prompt (injected near end to reinforce instructions in long conversations)
        if let reminderPrompt, !reminderPrompt.isEmpty {
            let resolved = reminderPrompt.replacingTemplateVars(charName: character.name, userName: userName)
            messages.append(LLMMessage(role: .system, content: resolved))
        }

        // 13. Post-history instructions (appended as system message after history)
        if !postInstructions.isEmpty {
            messages.append(LLMMessage(role: .system, content: postInstructions))
        }

        // 14. Image generation injection prompt (when LLM-triggered mode is active)
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
