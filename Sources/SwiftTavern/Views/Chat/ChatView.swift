import SwiftUI
import AppKit

/// Main chat interface view
struct ChatView: View {
    @Bindable var appState: AppState
    @Bindable var chatVM: ChatViewModel

    @State private var showingChatStyleEditor = false
    @State private var autoScrollEnabled = true

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

            // Cross-chat search bar (toggleable)
            if chatVM.showingSearch {
                searchBar
                Divider()
            }

            // In-chat search bar
            if chatVM.showingInChatSearch {
                inChatSearchBar
                Divider()
            }

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        let allDisplayMessages = chatVM.displayMessages
                        let displayMessages = chatVM.showingBookmarksOnly
                            ? allDisplayMessages.enumerated().filter { $0.element.isBookmarked }
                            : Array(allDisplayMessages.enumerated())
                        ForEach(displayMessages, id: \.element.id) { index, message in
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
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(error)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                }
                                HStack(spacing: 8) {
                                    Button("Dismiss") {
                                        chatVM.errorMessage = nil
                                    }
                                    .controlSize(.small)
                                    .buttonStyle(.bordered)
                                    Button("Retry") {
                                        chatVM.errorMessage = nil
                                        chatVM.retryLastResponse()
                                    }
                                    .controlSize(.small)
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.08))
                            .cornerRadius(8)
                            .padding(.horizontal, 12)
                        }

                        // Generate button when last message is from user (no response yet)
                        if !chatVM.isGenerating,
                           chatVM.errorMessage == nil,
                           let lastMsg = chatVM.messages.last,
                           lastMsg.isUser {
                            Button(action: { chatVM.generateResponse() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12))
                                    Text("Generate Response")
                                        .font(.system(size: 12))
                                }
                            }
                            .controlSize(.small)
                            .buttonStyle(.borderedProminent)
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
                    if autoScrollEnabled {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
                .onChange(of: chatVM.streamingText) {
                    if autoScrollEnabled {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }
                .onChange(of: chatVM.isGenerating) { _, isGenerating in
                    if !isGenerating && autoScrollEnabled {
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
                activeModel: appState.currentAPIConfiguration()?.model,
                characterName: chatVM.characterName,
                tokenCount: chatVM.estimatedTokenCount,
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
        .onKeyPress(keys: [KeyEquivalent("z")], phases: .down) { keyPress in
            guard keyPress.modifiers.contains(.command) else { return .ignored }
            if chatVM.canUndo {
                chatVM.undo()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: [KeyEquivalent("r")], phases: .down) { keyPress in
            guard keyPress.modifiers.contains(.command) else { return .ignored }
            if !chatVM.isGenerating, let lastMsg = chatVM.messages.last, !lastMsg.isUser {
                chatVM.regenerateResponse()
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
        // Prompt preview sheet
        .sheet(isPresented: $chatVM.showingPromptPreview) {
            VStack(spacing: 0) {
                HStack {
                    Text("Prompt Preview")
                        .font(.headline)
                    Spacer()
                    Button("Done") { chatVM.showingPromptPreview = false }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding()

                Divider()

                ScrollView {
                    Text(chatVM.promptPreviewText)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .frame(minWidth: 600, minHeight: 400)
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

        let truncatedMessage: ChatMessage = {
            let limit = appState.settings.chatMessageLengthLimit
            if limit > 0 && message.mes.count > limit {
                var msg = message
                msg.mes = String(message.mes.prefix(limit)) + "\n\n*[Message truncated — \(message.mes.count) characters]*"
                return msg
            }
            return message
        }()

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
            message: truncatedMessage,
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
            onToggleBookmark: { chatVM.toggleBookmark(at: index) },
            onFork: { chatVM.forkFromMessage(at: index) },
            chatStyle: activeChatStyle,
            swipeInfo: swipe
        )
    }

    // MARK: - Chat Header

    private var showLabels: Bool {
        appState.settings.showChatButtonLabels
    }

    @ViewBuilder
    private func chatHeaderLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
            if showLabels {
                Text(title)
                    .font(.system(size: 11))
            }
        }
    }

    private var chatHeader: some View {
        HStack(spacing: 6) {
            if let character = appState.selectedCharacter {
                AvatarImageView(imageData: character.avatarData, name: character.card.data.name, size: AvatarImageView.sizeSmall)
                Text(character.card.data.name)
                    .font(.headline)
                    .underline(false)
                    .onTapGesture {
                        appState.selectedSidebarItem = .characterInfo(character.filename)
                    }
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .help("View character info")
            }

            if !chatVM.messages.isEmpty {
                Text("~\(chatVM.estimatedTokenCount) tokens")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Group {
                Button(action: {
                    chatVM.showingBookmarksOnly.toggle()
                }) {
                    chatHeaderLabel("Bookmarks", icon: chatVM.showingBookmarksOnly ? "star.fill" : "star")
                        .foregroundColor(chatVM.showingBookmarksOnly ? .yellow : .primary)
                }
                .help("Filter Bookmarked Messages")

                Button(action: {
                    autoScrollEnabled.toggle()
                }) {
                    chatHeaderLabel("Auto-Scroll", icon: autoScrollEnabled ? "arrow.down.circle.fill" : "arrow.down.circle")
                }
                .help(autoScrollEnabled ? "Disable Auto-Scroll" : "Enable Auto-Scroll")

                Button(action: { showingChatStyleEditor = true }) {
                    chatHeaderLabel("Style", icon: "paintbrush")
                }
                .help("Chat Style")

                Button(action: {
                    chatVM.showingInChatSearch.toggle()
                    if !chatVM.showingInChatSearch {
                        chatVM.inChatSearchQuery = ""
                        chatVM.inChatSearchResults = []
                    }
                }) {
                    chatHeaderLabel("Find", icon: "magnifyingglass")
                }
                .help("Search in Chat (Cmd+F)")
                .keyboardShortcut("f", modifiers: .command)

                Button(action: { chatVM.showingSearch.toggle() }) {
                    chatHeaderLabel("Search All", icon: "text.magnifyingglass")
                }
                .help("Search All Chats")

                Button(action: { chatVM.newChat() }) {
                    chatHeaderLabel("New Chat", icon: "plus.message")
                }
                .help("New Chat (Cmd+N)")

                Button(action: { chatVM.showingChatPicker = true }) {
                    chatHeaderLabel("History", icon: "clock.arrow.circlepath")
                }
                .help("Chat History")

                Menu {
                    Button("Export Chat") { chatVM.exportCurrentChat() }
                    Button("Export as Markdown") { chatVM.exportAsMarkdown() }
                    Button("Import Chat") { chatVM.showingChatImporter = true }
                    Divider()
                    Button("View Prompt") {
                        chatVM.generatePromptPreview()
                        chatVM.showingPromptPreview = true
                    }
                } label: {
                    chatHeaderLabel("More", icon: "square.and.arrow.up")
                }
                .help("Export / Import")

            }
            .buttonStyle(.borderless)

            if chatVM.canUndo {
                Button(action: { chatVM.undo() }) {
                    chatHeaderLabel("Undo", icon: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Undo: \(chatVM.lastUndoDescription ?? "") (Cmd+Z)")
            }

            if !chatVM.isGenerating, let lastMsg = chatVM.messages.last, !lastMsg.isUser {
                Button(action: { chatVM.regenerateResponse() }) {
                    chatHeaderLabel("Regenerate", icon: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Regenerate Last Response")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

    // MARK: - In-Chat Search Bar

    private var inChatSearchBar: some View {
        HStack(spacing: 8) {
            TextField("Find in conversation...", text: $chatVM.inChatSearchQuery)
                .textFieldStyle(.roundedBorder)
                .onSubmit { chatVM.searchInCurrentChat() }

            if !chatVM.inChatSearchResults.isEmpty {
                Text("\(chatVM.currentSearchResultIndex + 1)/\(chatVM.inChatSearchResults.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                Button(action: { chatVM.previousSearchResult() }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)

                Button(action: { chatVM.nextSearchResult() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
            } else if !chatVM.inChatSearchQuery.isEmpty {
                Text("No matches")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Button("Find") { chatVM.searchInCurrentChat() }
                .controlSize(.small)

            Button(action: {
                chatVM.showingInChatSearch = false
                chatVM.inChatSearchQuery = ""
                chatVM.inChatSearchResults = []
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
