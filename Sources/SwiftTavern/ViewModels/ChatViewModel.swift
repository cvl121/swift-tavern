import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// ViewModel for the active chat interface
@Observable
final class ChatViewModel {
    var inputText = ""
    var isGenerating = false
    var streamingText = ""
    var errorMessage: String?
    var showingChatPicker = false
    var showingSearch = false
    var searchQuery = ""
    var searchResults: [(filename: String, matchingMessages: [ChatMessage])] = []
    var hasSearched = false
    var inChatSearchQuery = ""
    var inChatSearchResults: [Int] = []
    var currentSearchResultIndex = 0
    var showingInChatSearch = false
    var editingMessageIndex: Int?
    var editingText = ""
    var showDeleteConfirmation = false
    var pendingDeleteIndex: Int?
    var showingChatImporter = false
    var showingChatExporter = false
    var exportDocument: JSONDocument?
    var exportFilename: String?

    // Bookmark filter
    var showingBookmarksOnly = false

    // Prompt preview
    var showingPromptPreview = false
    var promptPreviewText = ""

    // Undo stack
    private var undoStack: [(description: String, messages: [ChatMessage])] = []
    private let maxUndoSteps = 10
    var canUndo: Bool { !undoStack.isEmpty }
    var lastUndoDescription: String? { undoStack.last?.description }

    /// Index into the combined greetings array for the first message swipe.
    /// 0 = firstMes, 1..N = alternateGreetings[0..N-1]
    var greetingSwipeIndex: Int = 0

    private weak var appState: AppState?
    private var generationTask: Task<Void, Never>?
    private static let streamTimeoutSeconds: Double = 120

    init(appState: AppState) {
        self.appState = appState
    }

    var messages: [ChatMessage] {
        appState?.currentChat?.messages ?? []
    }

    /// Messages to display, respecting the configured display limit
    var displayMessages: [ChatMessage] {
        guard let appState else { return [] }
        let allMessages = appState.currentChat?.messages ?? []
        let limit = appState.settings.chatDisplayLimit
        if limit > 0 && allMessages.count > limit {
            return Array(allMessages.suffix(limit))
        }
        return allMessages
    }

    /// Truncate a message for display if a length limit is set
    func displayText(for message: ChatMessage) -> String {
        guard let appState else { return message.mes }
        let limit = appState.settings.chatMessageLengthLimit
        if limit > 0 && message.mes.count > limit {
            return String(message.mes.prefix(limit)) + "..."
        }
        return message.mes
    }

    /// Check if a message should be truncated for display
    var messageLengthLimit: Int {
        appState?.settings.chatMessageLengthLimit ?? 0
    }

    var characterName: String {
        appState?.selectedCharacter?.card.data.name ?? "Character"
    }

    var userName: String {
        appState?.settings.userName ?? "User"
    }

    /// Persist the current state of a chat session to disk
    func rewriteChat(_ session: ChatSession) {
        guard let appState else { return }
        try? appState.chatStorage.rewriteChat(session, characterName: characterName)
    }

    // MARK: - Send Message

    func sendMessage() {
        guard let appState, !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let messageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""

        let userMessage = ChatMessage(name: userName, isUser: true, mes: messageText)
        appState.currentChat?.messages.append(userMessage)

        if let chat = appState.currentChat, let character = appState.selectedCharacter {
            do {
                try appState.chatStorage.appendMessage(
                    userMessage,
                    characterName: character.card.data.name,
                    filename: chat.filename
                )
            } catch {
                errorMessage = "Failed to save message: \(error.localizedDescription)"
            }
        }

        generateResponse()
    }

    // MARK: - Generate Response (with timeout)

    func generateResponse() {
        guard let appState,
              let character = appState.selectedCharacter,
              let config = appState.currentAPIConfiguration() else {
            errorMessage = "No API configured. Go to Settings > API Provider to set up your API key and select a model."
            return
        }

        isGenerating = true
        streamingText = ""
        errorMessage = nil

        let service = appState.currentLLMService()
        let chatHistory = appState.currentChat?.messages ?? []
        // Capture character name and chat filename at generation start to prevent
        // race conditions if user switches characters during generation
        let charName = character.card.data.name
        let chatFilename = appState.currentChat?.filename

        let worldInfoEntries = resolveWorldInfoEntries(for: character, appState: appState)

        let persona = appState.personas.first { $0.name == appState.settings.userName }

        let llmMessages = PromptBuilder.buildMessages(
            character: character.card.data,
            chatHistory: chatHistory,
            userName: appState.settings.userName,
            systemPrompt: appState.settings.defaultSystemPrompt,
            worldInfoEntries: worldInfoEntries,
            persona: persona
        )

        let shouldStream = config.generationParams.streamResponse

        // Developer mode logging
        appState.devLogger.log(.request, "[\(config.apiType.displayName)] POST \(config.effectiveBaseURL) | Model: \(config.model) | Messages: \(llmMessages.count) | Stream: \(shouldStream)")

        generationTask = Task {
            do {
                if shouldStream {
                    let stream = service.sendMessage(messages: llmMessages, config: config)

                    // Timeout wrapper
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            for try await chunk in stream {
                                try Task.checkCancellation()
                                await MainActor.run {
                                    self.streamingText += chunk
                                }
                            }
                        }

                        group.addTask {
                            try await Task.sleep(for: .seconds(Self.streamTimeoutSeconds))
                            throw LLMError.streamingError("Response timed out after \(Int(Self.streamTimeoutSeconds))s")
                        }

                        // Wait for first to complete (either stream finishes or timeout)
                        if let result = try await group.nextResult() {
                            group.cancelAll()
                            try result.get()
                        }
                    }
                } else {
                    let response = try await service.sendMessageComplete(messages: llmMessages, config: config)
                    await MainActor.run {
                        self.streamingText = response
                    }
                }

                await MainActor.run {
                    // Only finalize if we're still on the same chat
                    guard appState.currentChat?.filename == chatFilename else {
                        isGenerating = false
                        streamingText = ""
                        return
                    }
                    appState.devLogger.log(.response, "[\(config.apiType.displayName)] Response received | Model: \(config.model) | Length: \(self.streamingText.count) chars")
                    finalizeResponse(characterName: charName)
                }
            } catch is CancellationError {
                appState.devLogger.log(.info, "[\(config.apiType.displayName)] Request cancelled by user")
            } catch {
                appState.devLogger.log(.error, "[\(config.apiType.displayName)] Error: \(error.localizedDescription)")
                await MainActor.run {
                    if !self.streamingText.isEmpty {
                        finalizeResponse(characterName: charName)
                        errorMessage = "Partial response saved. Error: \(error.localizedDescription)"
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    isGenerating = false
                }
            }
        }
    }

    private func finalizeResponse(characterName: String) {
        guard let appState, !streamingText.isEmpty else {
            isGenerating = false
            return
        }

        var assistantMessage = ChatMessage(
            name: characterName,
            isUser: false,
            mes: streamingText
        )

        // If we have pending swipes from regeneration, attach them
        if var swipes = pendingSwipes {
            swipes.append(streamingText)
            assistantMessage.swipes = swipes
            assistantMessage.swipeId = swipes.count - 1
            pendingSwipes = nil
        }

        appState.currentChat?.messages.append(assistantMessage)

        if let chat = appState.currentChat {
            try? appState.chatStorage.rewriteChat(chat, characterName: characterName)
        }

        streamingText = ""
        isGenerating = false
    }

    // MARK: - Retry Last Response

    func retryLastResponse() {
        guard let appState, !isGenerating else { return }

        // Save old response as swipe before removing
        if let lastIndex = appState.currentChat?.messages.indices.last,
           let lastMsg = appState.currentChat?.messages[lastIndex],
           !lastMsg.isUser {
            var swipes = lastMsg.swipes ?? [lastMsg.mes]
            // Store the current text if not already in swipes
            if !swipes.contains(lastMsg.mes) {
                swipes.append(lastMsg.mes)
            }
            pendingSwipes = swipes
            appState.currentChat?.messages.removeLast()
            rewriteCurrentChat()
        }

        generateResponse()
    }

    // MARK: - Regenerate (alias for retry)

    func regenerateResponse() {
        retryLastResponse()
    }

    private var pendingSwipes: [String]?

    // MARK: - Stop

    func stopGenerating() {
        generationTask?.cancel()
        generationTask = nil

        if !streamingText.isEmpty, let appState, let character = appState.selectedCharacter {
            finalizeResponse(characterName: character.card.data.name)
        } else {
            streamingText = ""
            isGenerating = false
        }
    }

    // MARK: - Undo

    private func pushUndo(_ description: String) {
        guard let appState, let messages = appState.currentChat?.messages else { return }
        undoStack.append((description: description, messages: messages))
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
    }

    func undo() {
        guard let appState, let last = undoStack.popLast() else { return }
        appState.currentChat?.messages = last.messages
        rewriteCurrentChat()
        appState.showToast("Undid: \(last.description)")
    }

    // MARK: - Message Actions

    /// Copy message text to clipboard
    func copyMessage(at index: Int) {
        guard index < messages.count else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(messages[index].mes, forType: .string)
    }

    /// Begin editing a message
    func beginEditMessage(at index: Int) {
        guard index < messages.count else { return }
        editingMessageIndex = index
        editingText = messages[index].mes
    }

    /// Save an edited message
    func saveEditedMessage() {
        guard let appState, let index = editingMessageIndex,
              index < (appState.currentChat?.messages.count ?? 0) else {
            cancelEdit()
            return
        }

        pushUndo("edit message")
        appState.currentChat?.messages[index].mes = editingText
        rewriteCurrentChat()
        cancelEdit()
    }

    /// Cancel editing
    func cancelEdit() {
        editingMessageIndex = nil
        editingText = ""
    }

    /// Request deletion of a message (shows confirmation)
    func requestDeleteMessage(at index: Int) {
        pendingDeleteIndex = index
        showDeleteConfirmation = true
    }

    /// Confirm and delete a message
    func confirmDeleteMessage() {
        guard let appState, let index = pendingDeleteIndex,
              index < (appState.currentChat?.messages.count ?? 0) else {
            showDeleteConfirmation = false
            pendingDeleteIndex = nil
            return
        }

        pushUndo("delete message")
        appState.currentChat?.messages.remove(at: index)
        rewriteCurrentChat()
        showDeleteConfirmation = false
        pendingDeleteIndex = nil
    }

    /// Delete a message and all messages after it (rewind conversation)
    func deleteMessageAndAfter(at index: Int) {
        guard let appState, index < (appState.currentChat?.messages.count ?? 0), index > 0 else { return }
        pushUndo("delete messages")
        appState.currentChat?.messages.removeSubrange(index...)
        rewriteCurrentChat()
    }

    // MARK: - Response Swipes

    /// Swipe through alternative responses on the last assistant message.
    func swipeResponse(direction: Int) {
        guard let appState, let chat = appState.currentChat else { return }
        guard let lastIndex = chat.messages.indices.last,
              !chat.messages[lastIndex].isUser else { return }

        var msg = chat.messages[lastIndex]
        let swipes = msg.swipes ?? [msg.mes]
        let currentId = msg.swipeId ?? 0
        let newId = currentId + direction

        guard newId >= 0, newId < swipes.count else { return }

        msg.swipeId = newId
        msg.mes = swipes[newId]
        msg.swipes = swipes
        appState.currentChat?.messages[lastIndex] = msg
        rewriteCurrentChat()
    }

    // MARK: - Chat Search

    func performSearch() {
        guard let appState, let character = appState.selectedCharacter,
              !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            hasSearched = false
            return
        }

        searchResults = (try? appState.chatStorage.searchChats(
            characterName: character.card.data.name,
            query: searchQuery
        )) ?? []
        hasSearched = true
    }

    // MARK: - In-Chat Search

    func searchInCurrentChat() {
        let query = inChatSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            inChatSearchResults = []
            currentSearchResultIndex = 0
            return
        }

        inChatSearchResults = messages.enumerated().compactMap { index, message in
            message.mes.localizedCaseInsensitiveContains(query) ? index : nil
        }
        currentSearchResultIndex = inChatSearchResults.isEmpty ? 0 : 0
    }

    func nextSearchResult() {
        guard !inChatSearchResults.isEmpty else { return }
        currentSearchResultIndex = (currentSearchResultIndex + 1) % inChatSearchResults.count
    }

    func previousSearchResult() {
        guard !inChatSearchResults.isEmpty else { return }
        currentSearchResultIndex = (currentSearchResultIndex - 1 + inChatSearchResults.count) % inChatSearchResults.count
    }

    // MARK: - Chat Management

    func newChat() {
        guard let appState, let character = appState.selectedCharacter else { return }
        appState.currentChat = try? appState.chatStorage.createChat(
            characterName: character.card.data.name,
            userName: appState.settings.userName,
            firstMessage: character.card.data.firstMes
        )
        greetingSwipeIndex = 0
        appState.saveActiveChatFilename()
        appState.showToast("New chat created")
    }

    func loadChat(filename: String) {
        guard let appState, let character = appState.selectedCharacter else { return }
        appState.currentChat = try? appState.chatStorage.loadChat(
            characterName: character.card.data.name,
            filename: filename
        )
        syncGreetingSwipeIndex()
        appState.saveActiveChatFilename()
    }

    func deleteCurrentChat() {
        guard let appState, let character = appState.selectedCharacter,
              let chat = appState.currentChat else { return }

        try? appState.chatStorage.deleteChat(
            characterName: character.card.data.name,
            filename: chat.filename
        )

        if let chats = try? appState.chatStorage.listChats(for: character.card.data.name),
           let mostRecent = chats.first {
            appState.currentChat = try? appState.chatStorage.loadChat(
                characterName: character.card.data.name,
                filename: mostRecent.filename
            )
        } else {
            newChat()
        }
    }

    func chatList() -> [(filename: String, date: Date?)] {
        guard let appState, let character = appState.selectedCharacter else { return [] }
        return (try? appState.chatStorage.listChats(for: character.card.data.name)) ?? []
    }

    // MARK: - Greeting Swipes

    /// All available greetings: firstMes followed by alternateGreetings.
    var allGreetings: [String] {
        guard let character = appState?.selectedCharacter else { return [] }
        let data = character.card.data
        var greetings = [data.firstMes]
        greetings.append(contentsOf: data.alternateGreetings)
        return greetings
    }

    /// Whether the first message in this chat is a greeting that can be swiped.
    var hasGreetingSwipes: Bool {
        allGreetings.count > 1
    }

    var canSwipeGreetingLeft: Bool {
        greetingSwipeIndex > 0
    }

    var canSwipeGreetingRight: Bool {
        greetingSwipeIndex < allGreetings.count - 1
    }

    func swipeGreeting(direction: Int) {
        let newIndex = greetingSwipeIndex + direction
        guard newIndex >= 0, newIndex < allGreetings.count else { return }
        greetingSwipeIndex = newIndex
        applyGreetingSwipe()
    }

    private func applyGreetingSwipe() {
        guard let appState,
              appState.currentChat != nil,
              !allGreetings.isEmpty,
              greetingSwipeIndex < allGreetings.count else { return }

        let newText = allGreetings[greetingSwipeIndex]

        // Update the first non-system message (the greeting)
        if let firstMsgIndex = appState.currentChat?.messages.firstIndex(where: { !$0.isUser && !$0.isSystem }) {
            appState.currentChat?.messages[firstMsgIndex].mes = newText
            // Store swipe metadata
            appState.currentChat?.messages[firstMsgIndex].swipes = allGreetings
            appState.currentChat?.messages[firstMsgIndex].swipeId = greetingSwipeIndex
            rewriteCurrentChat()
        }
    }

    /// Sync the swipe index when loading a chat that already has a swiped greeting.
    func syncGreetingSwipeIndex() {
        guard let appState,
              let chat = appState.currentChat,
              let firstMsg = chat.messages.first(where: { !$0.isUser && !$0.isSystem }) else {
            greetingSwipeIndex = 0
            return
        }
        if let savedIndex = firstMsg.swipeId {
            greetingSwipeIndex = savedIndex
        } else {
            greetingSwipeIndex = 0
        }
    }

    // MARK: - Bookmarks

    func toggleBookmark(at index: Int) {
        guard let appState, index < (appState.currentChat?.messages.count ?? 0) else { return }
        appState.currentChat?.messages[index].isBookmarked.toggle()
        rewriteCurrentChat()
    }

    var bookmarkedMessages: [(Int, ChatMessage)] {
        messages.enumerated().compactMap { index, message in
            message.isBookmarked ? (index, message) : nil
        }
    }

    // MARK: - Fork Chat

    func forkFromMessage(at index: Int) {
        guard let appState, let chat = appState.currentChat,
              let character = appState.selectedCharacter,
              index < chat.messages.count else { return }

        let forkedMessages = Array(chat.messages[0...index])
        let charName = character.card.data.name

        do {
            var newSession = try appState.chatStorage.createChat(
                characterName: charName,
                userName: appState.settings.userName,
                firstMessage: nil
            )
            newSession.messages = forkedMessages
            try appState.chatStorage.rewriteChat(newSession, characterName: charName)
            appState.currentChat = newSession
            appState.showToast("Chat forked")
        } catch {
            errorMessage = "Failed to fork chat: \(error.localizedDescription)"
        }
    }

    // MARK: - World Info Resolution

    /// Resolve which world info entries to use: per-character > global > all books
    private func resolveWorldInfoEntries(for character: CharacterEntry, appState: AppState) -> [WorldInfoEntry] {
        // 1. Check per-character world lore (stored in extensions)
        let charWorldLore = character.card.data.extensions?["swifttavern_world_lore"]?.value as? String

        // 2. Fall back to global world lore setting
        let activeWorldLore = charWorldLore ?? appState.settings.globalWorldLore

        if let loreName = activeWorldLore,
           let book = appState.worldInfoBooks.first(where: { $0.name == loreName }) {
            return Array(book.entries.values)
        }

        // 3. No specific lore set — use all books
        var entries: [WorldInfoEntry] = []
        for book in appState.worldInfoBooks {
            entries.append(contentsOf: book.entries.values)
        }
        return entries
    }

    // MARK: - Prompt Preview

    func generatePromptPreview() {
        guard let appState,
              let character = appState.selectedCharacter else {
            promptPreviewText = "No character selected."
            return
        }

        let chatHistory = appState.currentChat?.messages ?? []
        let worldInfoEntries = resolveWorldInfoEntries(for: character, appState: appState)

        let persona = appState.personas.first { $0.name == appState.settings.userName }

        let llmMessages = PromptBuilder.buildMessages(
            character: character.card.data,
            chatHistory: chatHistory,
            userName: appState.settings.userName,
            systemPrompt: appState.settings.defaultSystemPrompt,
            worldInfoEntries: worldInfoEntries,
            persona: persona
        )

        promptPreviewText = llmMessages.map { msg in
            "[\(msg.role)]:\n\(msg.content)"
        }.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Token Count Estimation

    var estimatedTokenCount: Int {
        let allText = messages.map(\.mes).joined(separator: " ")
        guard !allText.isEmpty else { return 0 }
        let wordCount = allText.split(whereSeparator: { $0.isWhitespace }).count
        return Int(Double(wordCount) * 1.3)
    }

    // MARK: - Export as Markdown

    func exportAsMarkdown() {
        guard let appState, let chat = appState.currentChat,
              let character = appState.selectedCharacter else { return }

        let markdown = formatChatAsMarkdown(
            characterName: character.card.data.name,
            metadata: chat.metadata,
            messages: chat.messages
        )

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(character.card.data.name) - chat.md"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? markdown.write(to: url, atomically: true, encoding: .utf8)
                appState.showToast("Chat exported as Markdown")
            }
        }
    }

    func formatChatAsMarkdown(characterName: String, metadata: ChatMetadata, messages: [ChatMessage]) -> String {
        var lines: [String] = []
        lines.append("# Chat with \(characterName)")
        if let createDate = metadata.createDate {
            lines.append("Date: \(createDate)")
        }
        lines.append("")
        lines.append("---")
        lines.append("")

        for message in messages {
            lines.append("**\(message.name):** \(message.mes)")
            lines.append("")
            lines.append("---")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Export / Import

    func exportCurrentChat() {
        guard let appState, let chat = appState.currentChat,
              let character = appState.selectedCharacter else { return }
        if let jsonString = try? appState.chatStorage.exportChat(
            characterName: character.card.data.name,
            filename: chat.filename
        ), let data = jsonString.data(using: .utf8) {
            exportDocument = JSONDocument(data: data)
            exportFilename = chat.filename.replacingOccurrences(of: ".jsonl", with: ".json")
            showingChatExporter = true
        }
    }

    func importChat(from url: URL) {
        guard let appState, let character = appState.selectedCharacter else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        // Support importing JSONL chat files from SillyTavern
        guard let data = try? Data(contentsOf: url) else { return }
        guard let content = String(data: data, encoding: .utf8) else { return }

        let charName = character.card.data.name
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }

        // Try to parse as JSONL (SillyTavern native format)
        if lines.count > 1, let firstLine = lines.first?.data(using: .utf8),
           (try? JSONDecoder().decode(ChatMetadata.self, from: firstLine)) != nil {
            // Copy the file directly
            let destFilename = url.lastPathComponent
            let chatDir = appState.directoryManager.chatsDirectory.appendingPathComponent(charName)
            try? FileManager.default.createDirectory(at: chatDir, withIntermediateDirectories: true)
            let destURL = chatDir.appendingPathComponent(destFilename)
            try? data.write(to: destURL, options: .atomic)

            // Reload the chat
            if let session = try? appState.chatStorage.loadChat(characterName: charName, filename: destFilename) {
                appState.currentChat = session
            }
            return
        }

        // Try to parse as JSON export
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let messagesJson = json["messages"] as? [[String: Any]] {
            if var session = try? appState.chatStorage.createChat(
                characterName: charName,
                userName: appState.settings.userName,
                firstMessage: nil
            ) {
                for msgJson in messagesJson {
                    let msg = ChatMessage(
                        name: msgJson["name"] as? String ?? "Unknown",
                        isUser: msgJson["is_user"] as? Bool ?? false,
                        mes: msgJson["mes"] as? String ?? ""
                    )
                    session.messages.append(msg)
                    try? appState.chatStorage.appendMessage(msg, characterName: charName, filename: session.filename)
                }
                appState.currentChat = session
            }
        }
    }

    // MARK: - Private

    private func rewriteCurrentChat() {
        guard let appState, let chat = appState.currentChat,
              let character = appState.selectedCharacter else { return }
        do {
            try appState.chatStorage.rewriteChat(chat, characterName: character.card.data.name)
        } catch {
            errorMessage = "Failed to save chat: \(error.localizedDescription)"
        }
    }
}

/// Document wrapper for JSON file export
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
