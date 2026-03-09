import SwiftUI

/// Main sidebar with conversation list, groups, and navigation
struct SidebarView: View {
    @Bindable var appState: AppState
    @Bindable var characterListVM: CharacterListViewModel
    @Bindable var groupChatVM: GroupChatViewModel

    @State private var conversationSearchText = ""
    @State private var showGroupDeleteConfirmation = false
    @State private var pendingDeleteGroup: CharacterGroup?
    @State private var chatDateCache: [String: Date] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBarView(text: $conversationSearchText, placeholder: "Search conversations...")
                .padding(.horizontal, 4)
                .padding(.vertical, 6)

            // Scrollable conversation list
            List(selection: $appState.selectedSidebarItem) {
                Section("Conversations") {
                    if filteredConversations.isEmpty {
                        if conversationSearchText.isEmpty {
                            Text("No characters yet. Create or import one to start chatting.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            Text("No matches for \"\(conversationSearchText)\"")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        }
                    }

                    ForEach(filteredConversations) { entry in
                        ConversationRowView(
                            entry: entry,
                            lastMessageDate: lastChatDate(for: entry),
                            isSelected: appState.selectedSidebarItem == .character(entry.filename)
                        )
                        .tag(SidebarItem.character(entry.filename))
                        .onTapGesture {
                            characterListVM.selectCharacter(entry)
                        }
                        .contextMenu {
                            Button("Edit Character") {
                                characterListVM.editCharacter(entry)
                            }
                            Button("Export Character") {
                                characterListVM.exportCharacter(entry)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                characterListVM.requestDeleteCharacter(entry)
                            }
                        }
                    }
                }

                // Groups section - only shown when enabled
                if appState.settings.groupChatsEnabled {
                    Section("Groups") {
                        ForEach(appState.groups) { group in
                            Label(group.name, systemImage: "person.3")
                                .tag(SidebarItem.group(group.id))
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

                        Button(action: { groupChatVM.showingGroupEditor = true }) {
                            Label("New Group", systemImage: "plus")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider()

            // Bottom navigation buttons
            VStack(spacing: 0) {
                sidebarNavButton("Characters", icon: "person.text.rectangle", item: .characters)
                sidebarNavButton("World Lore", icon: "globe", item: .worldLore)
                sidebarNavButton("Personas", icon: "person.circle", item: .personas)

                Divider()
                    .padding(.vertical, 2)

                sidebarNavButton("Settings", icon: "gear", item: .settings)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
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
        // Delete confirmation
        .alert("Delete Character", isPresented: $characterListVM.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                characterListVM.pendingDeleteEntry = nil
            }
            Button("Delete", role: .destructive) {
                characterListVM.confirmDeleteCharacter()
            }
        } message: {
            Text("Are you sure you want to delete \"\(characterListVM.pendingDeleteEntry?.card.data.name ?? "")\"? This cannot be undone.")
        }
        .onAppear { refreshChatDates() }
        .onChange(of: appState.characters.count) { _, _ in refreshChatDates() }
        .onChange(of: appState.currentChat?.messages.count) { _, _ in refreshChatDates() }
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

    private func sidebarNavButton(_ title: String, icon: String, item: SidebarItem) -> some View {
        Button(action: { appState.selectedSidebarItem = item }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(appState.selectedSidebarItem == item ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(appState.selectedSidebarItem == item ? .accentColor : .primary)
        .accessibilityLabel(title)
        .help(title)
    }

    private var filteredConversations: [CharacterEntry] {
        if conversationSearchText.isEmpty {
            return characterListVM.filteredCharacters
        }
        return characterListVM.filteredCharacters.filter {
            $0.card.data.name.localizedCaseInsensitiveContains(conversationSearchText)
        }
    }

    /// Get the last chat date for a character (from cache)
    private func lastChatDate(for entry: CharacterEntry) -> Date? {
        chatDateCache[entry.card.data.name]
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
}

/// A conversation row showing character avatar, name, and last message date
private struct ConversationRowView: View {
    let entry: CharacterEntry
    let lastMessageDate: Date?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            AvatarImageView(imageData: entry.avatarData, name: entry.card.data.name, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.card.data.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if let date = lastMessageDate {
                    Text(date.relativeDisplayString)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
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
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}
