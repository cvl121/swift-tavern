import SwiftUI
import AppKit

/// Main chat interface view
struct ChatView: View {
    @Bindable var appState: AppState
    @Bindable var chatVM: ChatViewModel

    @State private var showingChatStyleEditor = false
    @State private var lastStreamScrollTime: Date = .distantPast
    @State private var searchScope: SearchScope = .thisChat
    /// Auto-sized input text content height
    @State private var inputContentHeight: CGFloat = 28

    private let minInputHeight: CGFloat = 28
    private let maxInputHeight: CGFloat = 200

    private enum SearchScope: String, CaseIterable {
        case thisChat = "This Chat"
        case allChats = "All Chats"
    }

    // MARK: - Cached user avatar

    @State private var cachedUserAvatarData: Data?
    @State private var cachedUserAvatarKey: String = ""

    private var userAvatarData: Data? {
        let activePersona = appState.personas.first { $0.name == appState.settings.userName }
        let key = "\(appState.settings.userName)-\(activePersona?.avatarFilename ?? "")"
        if key == cachedUserAvatarKey { return cachedUserAvatarData }
        let data: Data?
        if let filename = activePersona?.avatarFilename {
            data = appState.personaStorage.loadAvatar(filename: filename)
        } else {
            data = nil
        }
        DispatchQueue.main.async {
            cachedUserAvatarKey = key
            cachedUserAvatarData = data
        }
        return data
    }

    private var activeChatStyle: ChatStyle? {
        appState.currentChat?.metadata.chatMetadata.chatStyle ?? appState.settings.chatStyle
    }

    private var hasConversationStyle: Bool {
        appState.currentChat?.metadata.chatMetadata.chatStyle != nil
    }

    // MARK: - Body

    /// The clamped height for the input text field
    private var effectiveInputHeight: CGFloat {
        min(max(inputContentHeight, minInputHeight), maxInputHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider()

            if chatVM.showingSearch || chatVM.showingInChatSearch {
                searchBar
                Divider()
            }

            // Messages — fills all available space
            messagesArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Input — auto-sized based on content
            Divider()
            inputPane
        }
        .overlay(alignment: .bottomTrailing) {
            if appState.isSaving {
                Text("Saving...")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .padding(8)
                    .transition(.opacity)
            }
        }
        .chatKeyboardShortcuts(chatVM: chatVM, appState: appState)
        .chatSheets(chatVM: chatVM, appState: appState, showingChatStyleEditor: $showingChatStyleEditor, activeChatStyle: activeChatStyle, hasConversationStyle: hasConversationStyle)
        .chatFileDialogs(chatVM: chatVM)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if let filename = appState.selectedCharacter?.filename {
                appState.markRead(characterFilename: filename)
            }
        }
        .alert("Delete Message", isPresented: $chatVM.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { chatVM.pendingDeleteIndex = nil }
            Button("Delete", role: .destructive) { chatVM.confirmDeleteMessage() }
        } message: {
            Text("Are you sure you want to delete this message? This cannot be undone.")
        }
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(chatVM.indexedDisplayMessages, id: \.element.stableIdentity) { offset, message in
                        messageBubble(index: offset, message: message)
                            .id(message.stableIdentity)
                    }

                    if chatVM.isGenerating {
                        StreamingIndicatorView(
                            characterName: chatVM.characterName,
                            text: chatVM.streamingText,
                            avatarData: appState.selectedCharacter?.avatarData,
                            chatStyle: activeChatStyle
                        )
                        .id("streaming")
                    }

                    statusBanners
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(FocusDismissBackground())
            .onAppear {
                if let anchor = chatVM.savedScrollAnchor() {
                    proxy.scrollTo(anchor, anchor: .top)
                } else {
                    scrollToEnd(proxy: proxy, animated: false)
                }
            }
            .onDisappear {
                chatVM.saveScrollPosition(visibleMessageID: nil)
            }
            .onChange(of: chatVM.messages.count) {
                guard chatVM.autoScrollEnabled else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    scrollToEnd(proxy: proxy, animated: true)
                }
            }
            .onChange(of: chatVM.streamingText) {
                guard chatVM.autoScrollEnabled else { return }
                let now = Date()
                if now.timeIntervalSince(lastStreamScrollTime) > 0.2 {
                    lastStreamScrollTime = now
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
            .onChange(of: chatVM.isGenerating) { oldVal, newVal in
                guard chatVM.autoScrollEnabled else { return }
                if newVal {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if chatVM.isGenerating {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scrollToEnd(proxy: proxy, animated: true)
                    }
                }
            }
            .onChange(of: chatVM.messages.last?.swipeId) {
                if let lastMsg = chatVM.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMsg.stableIdentity, anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatVM.editingMessageIndex) { _, newIndex in
                if let index = newIndex, index < chatVM.messages.count {
                    let id = chatVM.messages[index].stableIdentity
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .top)
                        }
                    }
                }
            }
            .onChange(of: chatVM.greetingSwipeIndex) {
                if let firstMsg = chatVM.messages.first {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(firstMsg.stableIdentity, anchor: .top)
                    }
                }
            }
        }
    }

    /// Scroll to the last real content in the list (last message or streaming indicator)
    private func scrollToEnd(proxy: ScrollViewProxy, animated: Bool) {
        let target: String
        if chatVM.isGenerating {
            target = "streaming"
        } else if let lastMsg = chatVM.messages.last {
            target = lastMsg.stableIdentity
        } else {
            return
        }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }

    // MARK: - Status Banners

    @ViewBuilder
    private var statusBanners: some View {
        if chatVM.isGeneratingImage {
            StatusBanner(icon: nil, color: .accentColor) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Generating image...").font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
        }

        if let imgError = chatVM.imageGenerationError {
            StatusBanner(icon: "photo.badge.exclamationmark", color: .orange) {
                HStack(spacing: 8) {
                    Text(imgError).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(2)
                    Spacer()
                    Button("Dismiss") { chatVM.imageGenerationError = nil }
                        .controlSize(.small).buttonStyle(.bordered)
                }
            }
        }

        if let error = chatVM.errorMessage {
            StatusBanner(icon: "exclamationmark.triangle.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(3)
                    HStack {
                        Spacer()
                        Button("Dismiss") { chatVM.errorMessage = nil }
                            .controlSize(.small).buttonStyle(.bordered)
                        Button("Retry") { chatVM.errorMessage = nil; chatVM.retryLastResponse() }
                            .controlSize(.small).buttonStyle(.borderedProminent)
                    }
                }
            }
        }

        if !chatVM.isGenerating, chatVM.errorMessage == nil,
           let lastMsg = chatVM.messages.last, lastMsg.isUser {
            Button(action: { chatVM.generateResponse() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12))
                    Text("Generate Response").font(.system(size: 12))
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Input Pane

    private var inputPane: some View {
        VStack(spacing: 0) {
            if chatVM.showStopOptions {
                HStack(spacing: 12) {
                    Image(systemName: "pause.circle").foregroundColor(.orange)
                    Text("Generation stopped. Keep partial response?")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                    Button("Discard") { chatVM.discardPartialResponse() }
                        .controlSize(.small).buttonStyle(.bordered)
                    Button("Keep") { chatVM.keepPartialResponse() }
                        .controlSize(.small).buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.04))
            }

            // Context info bar
            inputContextBar
                .padding(.horizontal, 12)
                .padding(.top, 6)

            // Input field + action buttons
            HStack(alignment: .bottom, spacing: 10) {
                NativeTextInput(
                    text: $chatVM.inputText,
                    font: .systemFont(ofSize: CGFloat(activeChatStyle?.fontSize ?? 13)),
                    onSubmit: { chatVM.sendMessage() },
                    sendOnEnter: appState.settings.sendOnEnter,
                    isGenerating: chatVM.isGenerating,
                    onStop: { chatVM.stopGenerating() },
                    onContentHeightChanged: { height in
                        inputContentHeight = height
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: effectiveInputHeight)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.separatorColor).opacity(0.4), lineWidth: 0.5)
                )
                .accessibilityLabel("Message input")

                inputActionButtons
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .padding(.top, 4)
        }
        .background(Color(.windowBackgroundColor))
    }

    private var inputContextBar: some View {
        HStack(spacing: 6) {
            if !chatVM.characterName.isEmpty {
                Text("Chatting with \(chatVM.characterName)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            if chatVM.estimatedTokenCount > 0 {
                Text("~\(chatVM.estimatedTokenCount) tokens")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if let model = appState.currentAPIConfiguration()?.model {
                Spacer()
                Text(model)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }

    private var inputActionButtons: some View {
        VStack(spacing: 6) {
            if appState.settings.imageGenerationSettings.enabled {
                Button(action: { chatVM.openImagePromptEditor() }) {
                    Image(systemName: chatVM.isGeneratingImage ? "hourglass" : "photo")
                        .font(.system(size: 15))
                        .foregroundColor(chatVM.isGeneratingImage ? .secondary : .accentColor)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(chatVM.isGeneratingImage || chatVM.isGenerating)
                .help("Generate an image of the current scene")
            }

            Button(action: {
                if chatVM.isGenerating {
                    chatVM.stopGenerating()
                } else if !chatVM.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    chatVM.sendMessage()
                }
            }) {
                Image(systemName: chatVM.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(chatVM.isGenerating ? .red : .accentColor)
            }
            .buttonStyle(.plain)
            .help(chatVM.isGenerating ? "Stop generating" : (appState.settings.sendOnEnter ? "Send (Enter)" : "Send (Cmd+Return)"))
            .animation(.easeInOut(duration: 0.15), value: chatVM.isGenerating)
        }
    }

    // MARK: - Chat Header

    @ViewBuilder
    private var contextUsageView: some View {
        let tokens = chatVM.estimatedTokenCount
        let model = appState.currentAPIConfiguration()?.model ?? ""
        let contextLimit = ModelContextLimits.contextWindow(for: model)

        if let limit = contextLimit {
            let ratio = min(Double(tokens) / Double(limit), 1.0)
            let color: Color = ratio > 0.9 ? .red : ratio > 0.7 ? .orange : .accentColor

            HStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.separatorColor).opacity(0.3))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color.opacity(0.6))
                            .frame(width: geo.size.width * ratio)
                    }
                }
                .frame(width: 40, height: 6)

                Text("~\(ModelContextLimits.formatTokenCount(tokens))/\(ModelContextLimits.formatTokenCount(limit))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .help("Estimated token usage: ~\(tokens) / \(limit) context window")
        } else {
            Text("~\(tokens) tokens")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func headerIcon(_ icon: String, active: Bool = false, tint: Color? = nil) -> some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: active ? .semibold : .regular))
            .foregroundColor(tint ?? (active ? .accentColor : .secondary))
    }

    private var chatHeader: some View {
        HStack(spacing: 4) {
            if let character = appState.selectedCharacter {
                AvatarImageView(imageData: character.avatarData, name: character.card.data.name, size: AvatarImageView.sizeSmall)
                Text(character.card.data.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .onTapGesture { appState.selectedSidebarItem = .characterInfo(character.filename) }
                    .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                    .help("View character info")
            }

            if !chatVM.messages.isEmpty {
                contextUsageView.padding(.leading, 4)
            }

            Spacer()

            HStack(spacing: 2) {
                Button(action: { chatVM.showingBookmarksOnly.toggle() }) {
                    headerIcon("star\(chatVM.showingBookmarksOnly ? ".fill" : "")",
                               active: chatVM.showingBookmarksOnly,
                               tint: chatVM.showingBookmarksOnly ? .yellow : nil)
                }
                .buttonStyle(ToolbarPillButtonStyle(isActive: chatVM.showingBookmarksOnly))
                .help("Filter Bookmarked Messages")

                Button(action: { chatVM.autoScrollEnabled.toggle() }) {
                    headerIcon("arrow.down.circle\(chatVM.autoScrollEnabled ? ".fill" : "")",
                               active: chatVM.autoScrollEnabled)
                }
                .buttonStyle(ToolbarPillButtonStyle(isActive: chatVM.autoScrollEnabled))
                .help(chatVM.autoScrollEnabled ? "Disable Auto-Scroll" : "Enable Auto-Scroll")

                headerDivider

                Button(action: { toggleSearch() }) {
                    headerIcon("magnifyingglass", active: chatVM.showingSearch || chatVM.showingInChatSearch)
                }
                .buttonStyle(ToolbarPillButtonStyle(isActive: chatVM.showingSearch || chatVM.showingInChatSearch))
                .disabled(chatVM.isGenerating)
                .help("Search Messages (Cmd+F)")
                .keyboardShortcut("f", modifiers: .command)

                Button(action: { chatVM.newChat() }) { headerIcon("plus.message") }
                    .buttonStyle(ToolbarPillButtonStyle()).help("New Chat (Cmd+N)")

                Button(action: { chatVM.showingChatPicker = true }) { headerIcon("clock.arrow.circlepath") }
                    .buttonStyle(ToolbarPillButtonStyle()).help("Chat History")

                if appState.settings.imageGenerationSettings.enabled {
                    Button(action: { chatVM.openImagePromptEditor() }) {
                        headerIcon(chatVM.isGeneratingImage ? "hourglass" : "photo")
                    }
                    .buttonStyle(ToolbarPillButtonStyle())
                    .disabled(chatVM.isGeneratingImage || chatVM.isGenerating)
                    .help("Generate Scene Image")
                }

                headerDivider

                Button(action: { showingChatStyleEditor = true }) { headerIcon("paintbrush") }
                    .buttonStyle(ToolbarPillButtonStyle()).help("Chat Style")

                if chatVM.canUndo {
                    Button(action: { chatVM.undo() }) { headerIcon("arrow.uturn.backward") }
                        .buttonStyle(ToolbarPillButtonStyle())
                        .help("Undo: \(chatVM.lastUndoDescription ?? "") (Cmd+Z)")
                }

                if !chatVM.isGenerating, let lastMsg = chatVM.messages.last, !lastMsg.isUser {
                    Button(action: { chatVM.regenerateResponse() }) { headerIcon("arrow.clockwise") }
                        .buttonStyle(ToolbarPillButtonStyle()).help("Regenerate Last Response")
                }

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
                    headerIcon("ellipsis.circle")
                }
                .buttonStyle(ToolbarPillButtonStyle())
                .help("More Actions")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var headerDivider: some View {
        Divider().frame(height: 16).padding(.horizontal, 2)
    }

    // MARK: - Search Bar

    private func toggleSearch() {
        let isOpen = chatVM.showingSearch || chatVM.showingInChatSearch
        if isOpen {
            chatVM.showingSearch = false
            chatVM.showingInChatSearch = false
            chatVM.searchQuery = ""
            chatVM.inChatSearchQuery = ""
            chatVM.inChatSearchResults = []
        } else {
            chatVM.showingInChatSearch = true
        }
    }

    private func dismissSearch() {
        chatVM.showingSearch = false
        chatVM.showingInChatSearch = false
        chatVM.searchQuery = ""
        chatVM.inChatSearchQuery = ""
        chatVM.inChatSearchResults = []
        chatVM.searchResults = []
    }

    private var searchBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Picker("", selection: $searchScope) {
                    ForEach(SearchScope.allCases, id: \.self) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: searchScope) { _, newScope in
                    chatVM.inChatSearchResults = []
                    chatVM.searchResults = []
                    chatVM.hasSearched = false
                    if newScope == .thisChat {
                        chatVM.showingInChatSearch = true
                        chatVM.showingSearch = false
                    } else {
                        chatVM.showingSearch = true
                        chatVM.showingInChatSearch = false
                    }
                }

                if searchScope == .thisChat {
                    TextField("Find in conversation...", text: $chatVM.inChatSearchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { chatVM.searchInCurrentChat() }
                } else {
                    TextField("Search all chats...", text: $chatVM.searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { chatVM.performSearch() }
                }

                if searchScope == .thisChat {
                    if !chatVM.inChatSearchResults.isEmpty {
                        Text("\(chatVM.currentSearchResultIndex + 1)/\(chatVM.inChatSearchResults.count)")
                            .font(.system(size: 11)).foregroundColor(.secondary).monospacedDigit()
                        Button(action: { chatVM.previousSearchResult() }) {
                            Image(systemName: "chevron.up").font(.system(size: 11))
                        }.buttonStyle(.borderless)
                        Button(action: { chatVM.nextSearchResult() }) {
                            Image(systemName: "chevron.down").font(.system(size: 11))
                        }.buttonStyle(.borderless)
                    } else if !chatVM.inChatSearchQuery.isEmpty {
                        Text("No matches").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }

                if searchScope == .allChats {
                    Button("Search") { chatVM.performSearch() }.controlSize(.small)
                }

                Button(action: dismissSearch) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if searchScope == .allChats {
                if !chatVM.searchResults.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(chatVM.searchResults, id: \.filename) { result in
                                Button("\(result.filename.prefix(30))... (\(result.matchingMessages.count))") {
                                    chatVM.loadChat(filename: result.filename)
                                    dismissSearch()
                                }
                                .controlSize(.small).buttonStyle(.bordered)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(height: 30)
                } else if chatVM.hasSearched {
                    Text("No results found for \"\(chatVM.searchQuery)\"")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                        .padding(.horizontal, 12).padding(.bottom, 4)
                }
            }
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
                return .init(
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
                return .init(
                    currentIndex: swipeId, totalCount: total,
                    canSwipeLeft: swipeId > 0, canSwipeRight: swipeId < total - 1,
                    onSwipeLeft: { chatVM.swipeResponse(direction: -1) },
                    onSwipeRight: { chatVM.swipeResponse(direction: 1) }
                )
            }
            return nil
        }()

        MessageBubbleView(
            message: truncatedMessage, avatarData: avatarData, index: index,
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
            imageBasePath: appState.directoryManager.generatedImagesDirectory,
            imageDisplaySize: appState.settings.imageGenerationSettings.displaySize,
            showActionLabels: appState.settings.showChatButtonLabels,
            isFocused: chatVM.focusedMessageIndex == index,
            swipeInfo: swipe
        )
    }
}

// MARK: - Status Banner

private struct StatusBanner<Content: View>: View {
    let icon: String?
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon).foregroundColor(color)
            }
            content
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.12), lineWidth: 0.5))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Keyboard Shortcuts

extension View {
    func chatKeyboardShortcuts(chatVM: ChatViewModel, appState: AppState) -> some View {
        self
            .onKeyPress(.escape) {
                if chatVM.isGenerating { chatVM.stopGenerating(); return .handled }
                if chatVM.editingMessageIndex != nil { chatVM.cancelEdit(); return .handled }
                return .ignored
            }
            .onKeyPress(keys: [KeyEquivalent("z")], phases: .down) { keyPress in
                guard keyPress.modifiers.contains(.command) else { return .ignored }
                if chatVM.canUndo { chatVM.undo(); return .handled }
                return .ignored
            }
            .onKeyPress(keys: [KeyEquivalent("r")], phases: .down) { keyPress in
                guard keyPress.modifiers.contains(.command) else { return .ignored }
                if !chatVM.isGenerating, let lastMsg = chatVM.messages.last, !lastMsg.isUser {
                    chatVM.regenerateResponse(); return .handled
                }
                return .ignored
            }
            .onKeyPress(.upArrow) {
                guard appState.settings.keyboardMessageNavEnabled else { return .ignored }
                chatVM.focusPreviousMessage(); return .handled
            }
            .onKeyPress(.downArrow) {
                guard appState.settings.keyboardMessageNavEnabled else { return .ignored }
                chatVM.focusNextMessage(); return .handled
            }
    }

    func chatSheets(
        chatVM: ChatViewModel,
        appState: AppState,
        showingChatStyleEditor: Binding<Bool>,
        activeChatStyle: ChatStyle?,
        hasConversationStyle: Bool
    ) -> some View {
        self
            .sheet(isPresented: Binding(get: { chatVM.showingChatPicker }, set: { chatVM.showingChatPicker = $0 })) {
                ChatHistoryPickerView(
                    chatList: chatVM.chatList(),
                    currentFilename: appState.currentChat?.filename,
                    onSelect: { chatVM.loadChat(filename: $0); chatVM.showingChatPicker = false },
                    onNew: { chatVM.newChat(); chatVM.showingChatPicker = false },
                    onDelete: { chatVM.deleteCurrentChat(); chatVM.showingChatPicker = false }
                )
            }
            .sheet(isPresented: showingChatStyleEditor) {
                ChatStyleEditorView(
                    chatStyle: Binding(
                        get: { activeChatStyle ?? .default },
                        set: { newStyle in
                            appState.currentChat?.metadata.chatMetadata.chatStyle = newStyle
                            if let chat = appState.currentChat { chatVM.rewriteChat(chat) }
                        }
                    ),
                    hasConversationOverride: hasConversationStyle,
                    onResetToGlobal: {
                        appState.currentChat?.metadata.chatMetadata.chatStyle = nil
                        if let chat = appState.currentChat { chatVM.rewriteChat(chat) }
                    }
                )
            }
            .sheet(isPresented: Binding(get: { chatVM.showingPromptPreview }, set: { chatVM.showingPromptPreview = $0 })) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Prompt Preview").font(.headline)
                        Spacer()
                        Button("Done") { chatVM.showingPromptPreview = false }
                            .buttonStyle(.borderedProminent).controlSize(.small)
                    }.padding()
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
            .sheet(isPresented: Binding(get: { chatVM.showingImagePromptEditor }, set: { chatVM.showingImagePromptEditor = $0 })) {
                ImagePromptEditorView(chatVM: chatVM, appState: appState)
            }
    }

    func chatFileDialogs(chatVM: ChatViewModel) -> some View {
        self
            .fileImporter(
                isPresented: Binding(get: { chatVM.showingChatImporter }, set: { chatVM.showingChatImporter = $0 }),
                allowedContentTypes: [.json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    chatVM.importChat(from: url)
                }
            }
            .fileExporter(
                isPresented: Binding(get: { chatVM.showingChatExporter }, set: { chatVM.showingChatExporter = $0 }),
                document: chatVM.exportDocument,
                contentType: .json,
                defaultFilename: chatVM.exportFilename
            ) { _ in chatVM.showingChatExporter = false }
    }
}

// MARK: - Focus Dismiss Background

private struct FocusDismissBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> FocusDismissNSView { FocusDismissNSView() }
    func updateNSView(_ nsView: FocusDismissNSView, context: Context) {}

    final class FocusDismissNSView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(nil)
            super.mouseDown(with: event)
        }
    }
}
