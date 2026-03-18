import SwiftUI
import UniformTypeIdentifiers

/// Main sidebar with conversation list, groups, and navigation
struct SidebarView: View {
    @Bindable var appState: AppState
    @Bindable var characterListVM: CharacterListViewModel
    @Bindable var groupChatVM: GroupChatViewModel

    @State private var showGroupDeleteConfirmation = false
    @State private var pendingDeleteGroup: CharacterGroup?
    @State private var showConversationDeleteConfirmation = false
    @State private var pendingDeleteConversationEntry: CharacterEntry?
    @State private var pendingDeleteMessageCount: Int = 0
    @State private var chatDateCache: [String: Date] = [:]
    @State private var hoveredCharacter: String?
    @State private var hoveredGroup: String?
    @State private var hoveredNavItem: SidebarItem?
    @State private var isDragTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable conversation list
            ScrollView {
                LazyVStack(spacing: 0) {
                    conversationsSection
                        .padding(.top, 38)
                    if appState.settings.groupChatsEnabled {
                        groupsSection
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .onDrop(of: [.png, .json, .fileURL], isTargeted: $isDragTargeted) { providers in
                handleDrop(providers: providers)
            }
            .overlay {
                if isDragTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.05))
                        .cornerRadius(8)
                        .padding(4)
                }
            }

            Divider()

            // Bottom navigation buttons
            navigationSection
        }
        .clipped()
        // Character file importer (for sidebar import button)
        .fileImporter(
            isPresented: $characterListVM.showingImporter,
            allowedContentTypes: [.png, .json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                characterListVM.importCharacter(from: url)
            }
        }
        // Export character file saver
        .fileExporter(
            isPresented: $characterListVM.showingExporter,
            document: characterListVM.exportDocument,
            contentType: .png,
            defaultFilename: characterListVM.exportFilename
        ) { result in
            characterListVM.showingExporter = false
        }
        // Delete character confirmation
        .alert("Delete Character", isPresented: $characterListVM.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                characterListVM.pendingDeleteEntry = nil
            }
            Button("Delete", role: .destructive) {
                characterListVM.confirmDeleteCharacter()
            }
        } message: {
            Text("Are you sure you want to delete \"\(characterListVM.pendingDeleteEntry?.card.data.name ?? "")\"? This will remove the character and all their chats. This cannot be undone.")
        }
        // Delete conversation confirmation
        .alert("Delete Conversation", isPresented: $showConversationDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingDeleteConversationEntry = nil
            }
            Button("Delete", role: .destructive) {
                deleteCurrentConversation()
            }
        } message: {
            Text("Are you sure you want to delete the current conversation with \"\(pendingDeleteConversationEntry?.card.data.name ?? "")\"\(pendingDeleteMessageCount > 0 ? " (\(pendingDeleteMessageCount) messages)" : "")? This cannot be undone.")
        }
        .onAppear { refreshChatDates() }
        .onChange(of: appState.characters.count) { _, _ in refreshChatDates() }
        .onChange(of: appState.currentChat?.messages.count) { _, _ in refreshCurrentChatDate() }
        // Group delete confirmation
        .alert("Delete Group", isPresented: $showGroupDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingDeleteGroup = nil
            }
            Button("Delete", role: .destructive) {
                if let group = pendingDeleteGroup {
                    try? appState.groupStorage.delete(id: group.id)
                    appState.groups.removeAll { $0.id == group.id }
                }
                pendingDeleteGroup = nil
            }
        } message: {
            Text("Are you sure you want to delete the group \"\(pendingDeleteGroup?.name ?? "")\"? This cannot be undone.")
        }
    }

    // MARK: - Conversations Section

    @ViewBuilder
    private var conversationsSection: some View {
        sectionHeader("Conversations")

        if filteredConversations.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                Text("No characters yet")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Button("Import Character") {
                    characterListVM.showingImporter = true
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }

        groupedConversationsList
    }

    @ViewBuilder
    private var groupedConversationsList: some View {
        ForEach(filteredConversations) { entry in
            characterConversationRow(entry: entry)
        }
    }

    private func characterConversationRow(entry: CharacterEntry) -> some View {
        ConversationRowView(
            entry: entry,
            lastMessageDate: lastChatDate(for: entry),
            isSelected: appState.selectedSidebarItem == .character(entry.filename),
            isHovered: hoveredCharacter == entry.filename,
            isPinned: appState.settings.pinnedCharacters.contains(entry.filename),
            hasUnread: appState.unreadCharacters.contains(entry.filename)
        )
        .onHover { hovering in
            hoveredCharacter = hovering ? entry.filename : nil
        }
        .onTapGesture {
            characterListVM.selectCharacter(entry)
        }
        .contextMenu {
            let isPinned = appState.settings.pinnedCharacters.contains(entry.filename)
            Button(isPinned ? "Unpin" : "Pin to Top") {
                if isPinned {
                    appState.settings.pinnedCharacters.removeAll { $0 == entry.filename }
                } else {
                    appState.settings.pinnedCharacters.append(entry.filename)
                }
                appState.saveSettings()
            }
            Divider()
            Button("Delete Conversation", role: .destructive) {
                pendingDeleteConversationEntry = entry
                // Count messages in the conversation to show in confirmation
                if appState.selectedCharacter?.filename == entry.filename,
                   let chat = appState.currentChat {
                    pendingDeleteMessageCount = chat.messages.count
                } else if let chats = try? appState.chatStorage.listChats(for: entry.card.data.name),
                          let mostRecent = chats.first,
                          let chat = try? appState.chatStorage.loadChat(characterName: entry.card.data.name, filename: mostRecent.filename) {
                    pendingDeleteMessageCount = chat.messages.count
                } else {
                    pendingDeleteMessageCount = 0
                }
                showConversationDeleteConfirmation = true
            }
        }
    }

    // MARK: - Groups Section

    @ViewBuilder
    private var groupsSection: some View {
        sectionHeader("Groups", topPadding: 12)

        ForEach(appState.groups) { group in
            groupRow(group)
        }

        newGroupButton
    }

    private func groupRow(_ group: CharacterGroup) -> some View {
        let isSelected = appState.selectedSidebarItem == .group(group.id)
        let isHovered = hoveredGroup == group.id
        return HStack(spacing: 8) {
            Image(systemName: "person.3")
                .font(.system(size: 12))
                .frame(width: 16)
            Text(group.name)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected
                    ? Color.accentColor.opacity(0.18)
                    : isHovered
                        ? Color.primary.opacity(0.06)
                        : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredGroup = hovering ? group.id : nil
        }
        .onTapGesture {
            groupChatVM.selectGroup(group)
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                pendingDeleteGroup = group
                showGroupDeleteConfirmation = true
            }
        }
    }

    private var newGroupButton: some View {
        Button(action: { groupChatVM.showingGroupEditor = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text("New Group")
                    .font(.system(size: 12))
            }
            .foregroundColor(.secondary)
            .padding(.vertical, 4)
            .padding(.leading, 4)
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String, topPadding: CGFloat = 6) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
            .padding(.top, topPadding)
            .padding(.bottom, 6)
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        VStack(spacing: 1) {
            sidebarNavButton("Characters", icon: "person.text.rectangle", item: .characters)
            sidebarNavButton("World Lore", icon: "globe", item: .worldLore)
            sidebarNavButton("Personas", icon: "person.circle", item: .personas)

            Divider()
                .padding(.vertical, 2)

            sidebarNavButton("Settings", icon: "gear", item: .settings)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    private func sidebarNavButton(_ title: String, icon: String, item: SidebarItem) -> some View {
        Button(action: { appState.selectedSidebarItem = item }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(appState.selectedSidebarItem == item
                        ? Color.accentColor.opacity(0.18)
                        : hoveredNavItem == item
                            ? Color.primary.opacity(0.06)
                            : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(appState.selectedSidebarItem == item ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { hovering in
            hoveredNavItem = hovering ? item : nil
        }
        .foregroundColor(appState.selectedSidebarItem == item ? .accentColor : .primary)
        .accessibilityLabel(title)
        .help(title)
    }

    private var filteredConversations: [CharacterEntry] {
        let pinned = Set(appState.settings.pinnedCharacters)
        return characterListVM.filteredCharacters.sorted { a, b in
            let aPinned = pinned.contains(a.filename)
            let bPinned = pinned.contains(b.filename)
            if aPinned != bPinned { return aPinned }
            // Within each group, sort by most recent chat date
            let aDate = chatDateCache[a.card.data.name] ?? .distantPast
            let bDate = chatDateCache[b.card.data.name] ?? .distantPast
            return aDate > bDate
        }
    }

    /// Get the last chat date for a character (from cache)
    private func lastChatDate(for entry: CharacterEntry) -> Date? {
        chatDateCache[entry.card.data.name]
    }

    /// Handle drag-and-drop of character files
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    let ext = url.pathExtension.lowercased()
                    if ext == "png" || ext == "json" {
                        DispatchQueue.main.async {
                            characterListVM.importCharacter(from: url)
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }

    /// Delete the current conversation for the pending entry
    private func deleteCurrentConversation() {
        guard let entry = pendingDeleteConversationEntry else { return }
        let name = entry.card.data.name

        // If this character is currently selected, delete the active chat
        if appState.selectedCharacter?.filename == entry.filename,
           let chat = appState.currentChat {
            try? appState.chatStorage.deleteChat(characterName: name, filename: chat.filename)
            // Load the next most recent chat, or create a new one
            if let chats = try? appState.chatStorage.listChats(for: name),
               let mostRecent = chats.first {
                appState.currentChat = try? appState.chatStorage.loadChat(
                    characterName: name,
                    filename: mostRecent.filename
                )
            } else {
                appState.currentChat = try? appState.chatStorage.createChat(
                    characterName: name,
                    userName: appState.settings.userName,
                    firstMessage: nil
                )
            }
        } else {
            // Character not currently selected — delete their most recent chat
            if let chats = try? appState.chatStorage.listChats(for: name),
               let mostRecent = chats.first {
                try? appState.chatStorage.deleteChat(characterName: name, filename: mostRecent.filename)
            }
        }

        pendingDeleteConversationEntry = nil
        refreshChatDates()
    }

    /// Refresh all chat dates in one pass
    private func refreshChatDates() {
        var cache: [String: Date] = [:]
        for entry in characterListVM.filteredCharacters {
            let name = entry.card.data.name
            if let chats = try? appState.chatStorage.listChats(for: name),
               let recent = chats.first {
                cache[name] = recent.date
            }
        }
        chatDateCache = cache
    }

    /// Refresh only the current character's chat date (avoids iterating all characters on each message)
    private func refreshCurrentChatDate() {
        guard let character = appState.selectedCharacter else { return }
        let name = character.card.data.name
        if let chats = try? appState.chatStorage.listChats(for: name),
           let recent = chats.first {
            chatDateCache[name] = recent.date
        }
    }
}

/// A conversation row showing character avatar, name, and last message date
private struct ConversationRowView: View {
    let entry: CharacterEntry
    let lastMessageDate: Date?
    let isSelected: Bool
    var isHovered: Bool = false
    var isPinned: Bool = false
    var hasUnread: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                AvatarImageView(imageData: entry.avatarData, name: entry.card.data.name, size: AvatarImageView.sizeMedium)
                if hasUnread {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color(.windowBackgroundColor), lineWidth: 1.5))
                        .offset(x: 2, y: -2)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.card.data.name)
                        .font(.system(size: 13, weight: hasUnread ? .bold : .medium))
                        .lineLimit(1)
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }

                if let date = lastMessageDate {
                    Text(date.relativeDisplayString)
                        .font(.system(size: 10))
                        .foregroundColor(hasUnread ? .accentColor : .secondary)
                        .lineLimit(1)
                } else if !entry.card.data.tags.isEmpty {
                    Text(entry.card.data.tags.prefix(3).joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.18)
                : isHovered
                    ? Color.primary.opacity(0.06)
                    : Color.clear
        )
        .contentShape(Rectangle())
    }
}

