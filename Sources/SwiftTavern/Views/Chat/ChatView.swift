import SwiftUI

/// Main chat interface view
struct ChatView: View {
    @Bindable var appState: AppState
    @Bindable var chatVM: ChatViewModel

    @State private var showingChatStyleEditor = false

    /// Load avatar data for the active user persona
    private var userAvatarData: Data? {
        let activePersona = appState.personas.first { $0.name == appState.settings.userName }
        guard let filename = activePersona?.avatarFilename else { return nil }
        return appState.personaStorage.loadAvatar(filename: filename)
    }

    private var activeChatStyle: ChatStyle? {
        appState.settings.chatStyle
    }

    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader

            Divider()

            // Search bar (toggleable)
            if chatVM.showingSearch {
                searchBar
                Divider()
            }

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(chatVM.messages.enumerated()), id: \.element.id) { index, message in
                            messageBubble(index: index, message: message)
                                .id(message.id)
                        }

                        // Streaming indicator
                        if chatVM.isGenerating {
                            StreamingIndicatorView(
                                characterName: chatVM.characterName,
                                text: chatVM.streamingText,
                                avatarData: appState.selectedCharacter?.avatarData,
                                chatStyle: activeChatStyle
                            )
                            .id("streaming")
                        }

                        // Error with retry
                        if let error = chatVM.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Button("Retry") {
                                    chatVM.errorMessage = nil
                                    chatVM.retryLastResponse()
                                }
                                .controlSize(.small)
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                        }

                        // Invisible anchor at the very bottom
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.vertical, 8)
                }
                .onAppear {
                    scrollToBottom(proxy: proxy, animated: false)
                }
                .onChange(of: chatVM.messages.count) {
                    scrollToBottom(proxy: proxy, animated: true)
                }
                .onChange(of: chatVM.streamingText) {
                    scrollToBottom(proxy: proxy, animated: false)
                }
                .onChange(of: chatVM.isGenerating) { _, isGenerating in
                    if !isGenerating {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
            }

            Divider()

            // Input area
            ChatInputView(
                text: $chatVM.inputText,
                isGenerating: chatVM.isGenerating,
                sendOnEnter: appState.settings.sendOnEnter,
                onSend: { chatVM.sendMessage() },
                onStop: { chatVM.stopGenerating() }
            )
        }
        // Keyboard shortcuts
        .onKeyPress(.escape) {
            if chatVM.isGenerating {
                chatVM.stopGenerating()
                return .handled
            }
            if chatVM.editingMessageIndex != nil {
                chatVM.cancelEdit()
                return .handled
            }
            return .ignored
        }
        .sheet(isPresented: $chatVM.showingChatPicker) {
            ChatHistoryPickerView(
                chatList: chatVM.chatList(),
                currentFilename: appState.currentChat?.filename,
                onSelect: { filename in
                    chatVM.loadChat(filename: filename)
                    chatVM.showingChatPicker = false
                },
                onNew: {
                    chatVM.newChat()
                    chatVM.showingChatPicker = false
                },
                onDelete: {
                    chatVM.deleteCurrentChat()
                    chatVM.showingChatPicker = false
                }
            )
        }
        .sheet(isPresented: $showingChatStyleEditor) {
            ChatStyleEditorView(chatStyle: Binding(
                get: { appState.settings.chatStyle },
                set: {
                    appState.settings.chatStyle = $0
                    appState.saveSettings()
                }
            ))
        }
        // Chat import
        .fileImporter(
            isPresented: $chatVM.showingChatImporter,
            allowedContentTypes: [.json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                chatVM.importChat(from: url)
            }
        }
        // Chat export
        .fileExporter(
            isPresented: $chatVM.showingChatExporter,
            document: chatVM.exportDocument,
            contentType: .json,
            defaultFilename: chatVM.exportFilename
        ) { _ in
            chatVM.showingChatExporter = false
        }
        // Delete confirmation
        .alert("Delete Message", isPresented: $chatVM.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                chatVM.pendingDeleteIndex = nil
            }
            Button("Delete", role: .destructive) {
                chatVM.confirmDeleteMessage()
            }
        } message: {
            Text("Are you sure you want to delete this message? This cannot be undone.")
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: - Message Bubble Builder

    @ViewBuilder
    private func messageBubble(index: Int, message: ChatMessage) -> some View {
        let isLastAssistant = !message.isUser && index == chatVM.messages.count - 1
        let isGreeting = index == 0 && !message.isUser && !message.isSystem
        let hasResponseSwipes = isLastAssistant && (message.swipes?.count ?? 0) > 1
        let avatarData = message.isUser ? userAvatarData : appState.selectedCharacter?.avatarData

        let swipe: MessageBubbleView.SwipeInfo? = {
            if isGreeting && chatVM.hasGreetingSwipes {
                return MessageBubbleView.SwipeInfo(
                    currentIndex: chatVM.greetingSwipeIndex,
                    totalCount: chatVM.allGreetings.count,
                    canSwipeLeft: chatVM.canSwipeGreetingLeft,
                    canSwipeRight: chatVM.canSwipeGreetingRight,
                    onSwipeLeft: { chatVM.swipeGreeting(direction: -1) },
                    onSwipeRight: { chatVM.swipeGreeting(direction: 1) }
                )
            } else if hasResponseSwipes {
                let swipeId = message.swipeId ?? 0
                let total = message.swipes?.count ?? 1
                return MessageBubbleView.SwipeInfo(
                    currentIndex: swipeId,
                    totalCount: total,
                    canSwipeLeft: swipeId > 0,
                    canSwipeRight: swipeId < total - 1,
                    onSwipeLeft: { chatVM.swipeResponse(direction: -1) },
                    onSwipeRight: { chatVM.swipeResponse(direction: 1) }
                )
            }
            return nil
        }()

        MessageBubbleView(
            message: message,
            avatarData: avatarData,
            index: index,
            isEditing: chatVM.editingMessageIndex == index,
            editText: $chatVM.editingText,
            onCopy: { chatVM.copyMessage(at: index) },
            onEdit: { chatVM.beginEditMessage(at: index) },
            onSaveEdit: { chatVM.saveEditedMessage() },
            onCancelEdit: { chatVM.cancelEdit() },
            onDelete: { chatVM.requestDeleteMessage(at: index) },
            onRegenerate: isLastAssistant ? { chatVM.regenerateResponse() } : nil,
            onDeleteAndAfter: index > 0 ? { chatVM.deleteMessageAndAfter(at: index) } : nil,
            chatStyle: activeChatStyle,
            swipeInfo: swipe
        )
    }

    // MARK: - Chat Header

    private var chatHeader: some View {
        HStack {
            if let character = appState.selectedCharacter {
                AvatarImageView(imageData: character.avatarData, name: character.card.data.name, size: 28)
                Text(character.card.data.name)
                    .font(.headline)
            }

            Spacer()

            Button(action: { showingChatStyleEditor = true }) {
                Image(systemName: "paintbrush")
            }
            .help("Chat Style")

            Button(action: { chatVM.showingSearch.toggle() }) {
                Image(systemName: "magnifyingglass")
            }
            .help("Search Chats (Cmd+F)")
            .keyboardShortcut("f", modifiers: .command)

            Button(action: { chatVM.newChat() }) {
                Image(systemName: "plus.message")
            }
            .help("New Chat (Cmd+N)")

            Button(action: { chatVM.showingChatPicker = true }) {
                Image(systemName: "clock.arrow.circlepath")
            }
            .help("Chat History")

            Menu {
                Button("Export Chat") { chatVM.exportCurrentChat() }
                Button("Import Chat") { chatVM.showingChatImporter = true }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Export / Import")

            if !chatVM.isGenerating,
               let lastMsg = chatVM.messages.last, !lastMsg.isUser {
                Button(action: { chatVM.regenerateResponse() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Regenerate Last Response")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .buttonStyle(.borderless)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        VStack(spacing: 6) {
            HStack {
                TextField("Search messages...", text: $chatVM.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { chatVM.performSearch() }

                Button("Search") { chatVM.performSearch() }
                    .controlSize(.small)

                Button(action: { chatVM.showingSearch = false; chatVM.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if !chatVM.searchResults.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(chatVM.searchResults, id: \.filename) { result in
                            Button("\(result.filename.prefix(30))... (\(result.matchingMessages.count) matches)") {
                                chatVM.loadChat(filename: result.filename)
                                chatVM.showingSearch = false
                            }
                            .controlSize(.small)
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 30)
            } else if chatVM.hasSearched {
                Text("No results found for \"\(chatVM.searchQuery)\"")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
        }
    }
}
