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
    @State private var pendingDeleteChatCount: Int = 0
    @State private var chatDateCache: [String: Date] = [:]
    @State private var hoveredCharacter: String?
    @State private var hoveredGroup: String?
    @State private var hoveredNavItem: SidebarItem?
    @State private var isDragTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Conversations (scrollable, fills available space)
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Conversations")
                    .padding(.top, 38)

                if filteredConversations.isEmpty {
                    emptyConversationsView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredConversations) { entry in
                                conversationRow(entry: entry)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxHeight: .infinity)
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

            // MARK: - Groups (optional, compact)
            if appState.settings.groupChatsEnabled {
                Divider()
                groupsSection
            }

            // MARK: - Bottom Navigation
            Divider()
            navigationSection
        }
        .clipped()
        // File importer
        .fileImporter(
            isPresented: $characterListVM.showingImporter,
            allowedContentTypes: [.png, .json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                characterListVM.previewImport(from: url)
            }
        }
        .sheet(isPresented: $characterListVM.showingImportPreview) {
            CharacterImportPreviewView(characterListVM: characterListVM)
        }
        // File exporter
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
                deleteAllConversations()
            }
        } message: {
            Text("Are you sure you want to delete all conversations with \"\(pendingDeleteConversationEntry?.card.data.name ?? "")\"\(pendingDeleteChatCount > 0 ? " (\(pendingDeleteChatCount) \(pendingDeleteChatCount == 1 ? "conversation" : "conversations"))" : "")? This will also remove the character from the sidebar. This cannot be undone.")
        }
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
        .onAppear { refreshChatDates() }
        .onChange(of: appState.characters.count) { _, _ in refreshChatDates() }
        .onChange(of: appState.currentChat?.messages.count) { _, _ in refreshCurrentChatDate() }
    }

    // MARK: - Conversations

    private var emptyConversationsView: some View {
        VStack(spacing: 8) {
            Spacer()
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
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func conversationRow(entry: CharacterEntry) -> some View {
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
                if let chats = try? appState.chatStorage.listChats(for: entry.card.data.name) {
                    pendingDeleteChatCount = chats.count
                } else {
                    pendingDeleteChatCount = 0
                }
                showConversationDeleteConfirmation = true
            }
        }
    }

    // MARK: - Groups

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Groups")

            ForEach(appState.groups) { group in
                groupRow(group)
            }

            Button(action: { groupChatVM.showingGroupEditor = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                    Text("New Group")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
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
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected
                ? DS.Colors.surfaceSelected
                : isHovered
                    ? DS.Colors.surfaceHover
                    : Color.clear
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

    // MARK: - Navigation

    private var navigationSection: some View {
        VStack(spacing: 2) {
            sidebarNavButton("Characters", icon: "person.text.rectangle", item: .characters)
            sidebarNavButton("World Lore", icon: "globe", item: .worldLore)
            sidebarNavButton("Personas", icon: "person.circle", item: .personas)

            Divider()
                .padding(.vertical, 3)
                .padding(.horizontal, 8)

            sidebarNavButton("Settings", icon: "gear", item: .settings)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
    }

    private func sidebarNavButton(_ title: String, icon: String, item: SidebarItem) -> some View {
        let isSelected = appState.selectedSidebarItem == item
        let isHover = hoveredNavItem == item

        return Button(action: { appState.selectedSidebarItem = item }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected
                        ? DS.Colors.surfaceSelected
                        : isHover
                            ? DS.Colors.surfaceHover
                            : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { hovering in
            hoveredNavItem = hovering ? item : nil
        }
        .foregroundColor(isSelected ? .accentColor : .primary)
        .accessibilityLabel(title)
        .help(title)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private var filteredConversations: [CharacterEntry] {
        let pinned = Set(appState.settings.pinnedCharacters)
        return characterListVM.filteredCharacters.sorted { a, b in
            let aPinned = pinned.contains(a.filename)
            let bPinned = pinned.contains(b.filename)
            if aPinned != bPinned { return aPinned }
            let aDate = chatDateCache[a.card.data.name] ?? .distantPast
            let bDate = chatDateCache[b.card.data.name] ?? .distantPast
            return aDate > bDate
        }
    }

    private func lastChatDate(for entry: CharacterEntry) -> Date? {
        chatDateCache[entry.card.data.name]
    }

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

    private func deleteAllConversations() {
        guard let entry = pendingDeleteConversationEntry else { return }
        let name = entry.card.data.name

        // Delete all chat files for this character
        if let chats = try? appState.chatStorage.listChats(for: name) {
            for chat in chats {
                try? appState.chatStorage.deleteChat(characterName: name, filename: chat.filename)
            }
        }

        // Clear selection if this character was active
        if appState.selectedCharacter?.filename == entry.filename {
            appState.setActiveCharacter(nil)
            appState.currentChat = nil
        }

        // Remove the character from the sidebar
        appState.characters.removeAll { $0.filename == entry.filename }

        // Also delete the character file itself
        try? appState.characterStorage.delete(filename: entry.filename)

        // Remove from pinned if applicable
        appState.settings.pinnedCharacters.removeAll { $0 == entry.filename }
        appState.saveSettings()

        pendingDeleteConversationEntry = nil
        refreshChatDates()
    }

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

    private func refreshCurrentChatDate() {
        guard let character = appState.selectedCharacter else { return }
        let name = character.card.data.name
        if let chats = try? appState.chatStorage.listChats(for: name),
           let recent = chats.first {
            chatDateCache[name] = recent.date
        }
    }
}

// MARK: - Conversation Row

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
                            .foregroundColor(.secondary.opacity(0.7))
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
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected
                ? DS.Colors.surfaceSelected
                : isHovered
                    ? DS.Colors.surfaceHover
                    : Color.clear
        )
        .contentShape(Rectangle())
    }
}
