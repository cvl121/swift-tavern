import Foundation
import SwiftUI

/// ViewModel for group chat management
@Observable
final class GroupChatViewModel {
    var inputText = ""
    var isGenerating = false
    var streamingText = ""
    var errorMessage: String?
    var showingGroupEditor = false

    private weak var appState: AppState?
    private var generationTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
    }

    var messages: [ChatMessage] {
        appState?.currentChat?.messages ?? []
    }

    var group: CharacterGroup? {
        appState?.selectedGroup
    }

    /// Get character entries for group members
    var memberCharacters: [CharacterEntry] {
        guard let appState, let group = appState.selectedGroup else { return [] }
        return group.members.compactMap { filename in
            appState.characters.first { $0.filename == filename }
        }
    }

    /// Create a new group
    func createGroup(name: String, members: [String]) {
        guard let appState else { return }
        var group = CharacterGroup(name: name, members: members)

        // Create initial chat
        if let chat = try? appState.groupChatStorage.createChat(
            groupName: name,
            userName: appState.settings.userName
        ) {
            group.chatId = chat.id
            group.chats = [chat.filename]
            appState.currentChat = chat
        }

        try? appState.groupStorage.save(group)
        appState.groups.append(group)
        appState.selectedGroup = group
        appState.selectedCharacter = nil
        appState.selectedSidebarItem = .group(group.id)
    }

    /// Select a group
    func selectGroup(_ group: CharacterGroup) {
        guard let appState else { return }
        appState.selectedGroup = group
        appState.selectedCharacter = nil
        appState.selectedSidebarItem = .group(group.id)

        // Load the current chat
        if let chatFilename = group.chats.last {
            appState.currentChat = try? appState.groupChatStorage.loadChat(filename: chatFilename)
        }
    }

    /// Send a message in the group chat
    func sendMessage() {
        guard let appState, let group = appState.selectedGroup,
              !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let messageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""

        let userMessage = ChatMessage(name: appState.settings.userName, isUser: true, mes: messageText)
        appState.currentChat?.messages.append(userMessage)

        if let chat = appState.currentChat {
            try? appState.groupChatStorage.appendMessage(userMessage, filename: chat.filename)
        }

        // Generate response from next character
        generateGroupResponse(group: group)
    }

    /// Generate a response from the next character in the group
    private func generateGroupResponse(group: CharacterGroup) {
        guard let appState, let config = appState.currentAPIConfiguration() else {
            errorMessage = "No API configured"
            return
        }

        // Determine next speaker based on manual override or activation strategy
        let activeMembers = group.members.filter { !group.disabledMembers.contains($0) }
        guard !activeMembers.isEmpty else { return }

        let nextSpeaker: String
        if let manual = manualNextSpeaker, activeMembers.contains(manual) {
            nextSpeaker = manual
            manualNextSpeaker = nil // Clear override after use
        } else {
            switch group.activationStrategy {
            case .roundRobin:
                let lastCharMessage = messages.last { !$0.isUser }
                if let lastSpeaker = lastCharMessage?.name,
                   let lastIdx = activeMembers.firstIndex(where: { filename in
                       appState.characters.first { $0.filename == filename }?.card.data.name == lastSpeaker
                   }) {
                    nextSpeaker = activeMembers[(lastIdx + 1) % activeMembers.count]
                } else {
                    nextSpeaker = activeMembers[0]
                }
            case .random:
                nextSpeaker = activeMembers.randomElement() ?? activeMembers[0]
            default:
                nextSpeaker = activeMembers[0]
            }
        }

        guard let speakerEntry = appState.characters.first(where: { $0.filename == nextSpeaker }) else { return }

        isGenerating = true
        streamingText = ""
        errorMessage = nil

        let service = appState.currentLLMService()
        let chatHistory = appState.currentChat?.messages ?? []

        let llmMessages = PromptBuilder.buildMessages(
            character: speakerEntry.card.data,
            chatHistory: chatHistory,
            userName: appState.settings.userName,
            systemPrompt: appState.settings.defaultSystemPrompt
        )

        generationTask = Task {
            do {
                for try await chunk in service.sendMessage(messages: llmMessages, config: config) {
                    await MainActor.run { streamingText += chunk }
                }

                await MainActor.run {
                    let response = ChatMessage(
                        name: speakerEntry.card.data.name,
                        isUser: false,
                        mes: streamingText
                    )
                    appState.currentChat?.messages.append(response)
                    if let chat = appState.currentChat {
                        try? appState.groupChatStorage.appendMessage(response, filename: chat.filename)
                    }
                    streamingText = ""
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    streamingText = ""
                    isGenerating = false
                }
            }
        }
    }

    /// Manual speaker override — when set, this character speaks next instead of using strategy
    var manualNextSpeaker: String?

    /// Predict the next speaker based on group activation strategy
    var predictedNextSpeaker: CharacterEntry? {
        guard let appState, let group = appState.selectedGroup else { return nil }
        let activeMembers = group.members.filter { !group.disabledMembers.contains($0) }
        guard !activeMembers.isEmpty else { return nil }

        // If manual override is set, use it
        if let manual = manualNextSpeaker {
            return appState.characters.first { $0.filename == manual }
        }

        let nextFilename: String
        switch group.activationStrategy {
        case .roundRobin:
            let lastCharMessage = messages.last { !$0.isUser }
            if let lastSpeaker = lastCharMessage?.name,
               let lastIdx = activeMembers.firstIndex(where: { filename in
                   appState.characters.first { $0.filename == filename }?.card.data.name == lastSpeaker
               }) {
                nextFilename = activeMembers[(lastIdx + 1) % activeMembers.count]
            } else {
                nextFilename = activeMembers[0]
            }
        case .random:
            nextFilename = activeMembers[0] // Can't predict random, show first
        default:
            nextFilename = activeMembers[0]
        }
        return appState.characters.first { $0.filename == nextFilename }
    }

    var editingMessageIndex: Int?
    var editingText = ""
    var showDeleteConfirmation = false
    var pendingDeleteIndex: Int?

    func copyMessage(at index: Int) {
        guard index < messages.count else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(messages[index].mes, forType: .string)
    }

    func beginEditMessage(at index: Int) {
        guard index < messages.count else { return }
        editingMessageIndex = index
        editingText = messages[index].mes
    }

    func saveEditedMessage() {
        guard let appState, let index = editingMessageIndex,
              index < (appState.currentChat?.messages.count ?? 0) else {
            cancelEdit()
            return
        }

        appState.currentChat?.messages[index].mes = editingText
        rewriteCurrentGroupChat()
        cancelEdit()
    }

    func cancelEdit() {
        editingMessageIndex = nil
        editingText = ""
    }

    func requestDeleteMessage(at index: Int) {
        pendingDeleteIndex = index
        showDeleteConfirmation = true
    }

    func confirmDeleteMessage() {
        guard let appState, let index = pendingDeleteIndex,
              index < (appState.currentChat?.messages.count ?? 0) else {
            showDeleteConfirmation = false
            pendingDeleteIndex = nil
            return
        }

        appState.currentChat?.messages.remove(at: index)
        rewriteCurrentGroupChat()
        showDeleteConfirmation = false
        pendingDeleteIndex = nil
    }

    func deleteMessage(at index: Int) {
        guard let appState, index < (appState.currentChat?.messages.count ?? 0) else { return }
        appState.currentChat?.messages.remove(at: index)
        rewriteCurrentGroupChat()
    }

    func editMessage(at index: Int, newText: String) {
        guard let appState, index < (appState.currentChat?.messages.count ?? 0) else { return }
        appState.currentChat?.messages[index].mes = newText
        rewriteCurrentGroupChat()
    }

    func regenerateLastMessage() {
        guard let appState, let group = appState.selectedGroup, !isGenerating else { return }

        // Remove last assistant message and regenerate
        if let lastIndex = appState.currentChat?.messages.indices.last,
           let lastMsg = appState.currentChat?.messages[lastIndex],
           !lastMsg.isUser {
            appState.currentChat?.messages.removeLast()
            rewriteCurrentGroupChat()
        }

        generateGroupResponse(group: group)
    }

    private func rewriteCurrentGroupChat() {
        guard let appState, let chat = appState.currentChat else { return }
        // Rewrite by recreating the file with metadata + all messages
        let fileURL = appState.directoryManager.groupChatsDirectory.appendingPathComponent(chat.filename)
        let encoder = JSONEncoder()
        var lines: [String] = []
        if let metadataData = try? encoder.encode(chat.metadata),
           let metadataLine = String(data: metadataData, encoding: .utf8) {
            lines.append(metadataLine)
        }
        for message in chat.messages {
            if let msgData = try? encoder.encode(message),
               let msgLine = String(data: msgData, encoding: .utf8) {
                lines.append(msgLine)
            }
        }
        let content = lines.joined(separator: "\n") + "\n"
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func stopGenerating() {
        generationTask?.cancel()
        generationTask = nil
        streamingText = ""
        isGenerating = false
    }

    func deleteGroup() {
        guard let appState, let group = appState.selectedGroup else { return }
        try? appState.groupStorage.delete(id: group.id)
        appState.groups.removeAll { $0.id == group.id }
        appState.selectedGroup = nil
        appState.currentChat = nil
    }
}
