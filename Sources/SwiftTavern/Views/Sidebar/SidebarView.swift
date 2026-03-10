import SwiftUI
import UniformTypeIdentifiers

/// Main sidebar with conversation list, groups, and navigation
struct SidebarView: View {
    @Bindable var appState: AppState
    @Bindable var characterListVM: CharacterListViewModel
    @Bindable var groupChatVM: GroupChatViewModel

    @State private var conversationSearchText = ""
    @State private var showGroupDeleteConfirmation = false
    @State private var pendingDeleteGroup: CharacterGroup?
    @State private var chatDateCache: [String: Date] = [:]
    @State private var hoveredCharacter: String?
    @State private var hoveredGroup: String?
    @State private var hoveredNavItem: SidebarItem?
    @State private var isDragTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBarView(text: $conversationSearchText, placeholder: "Search conversations...", debounceInterval: 0.25)
                .padding(.top, 30)
                .padding(.bottom, 6)

            // Scrollable conversation list
            ScrollView {
                LazyVStack(spacing: 2) {
                    conversationsSection
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

    // MARK: - Conversations Section

    @ViewBuilder
    private var conversationsSection: some View {
        sectionHeader("Conversations")

        if filteredConversations.isEmpty {
            if conversationSearchText.isEmpty {
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
            } else {
                Text("No matches for \"\(conversationSearchText)\"")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                    .padding(.leading, 4)
            }
        }

        if appState.settings.showIndividualConversations {
            individualConversationsList
        } else {
            groupedConversationsList
        }
    }

    @ViewBuilder
    private var groupedConversationsList: some View {
        ForEach(filteredConversations) { entry in
            characterConversationRow(entry: entry)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var individualConversationsList: some View {
        ForEach(individualConversations, id: \.id) { item in
            IndividualConversationRowView(
                item: item,
                isSelected: appState.selectedSidebarItem == .character(item.entry.filename)
                    && appState.currentChat?.filename == item.chatFilename,
                isHovered: hoveredCharacter == item.id
            )
            .onHover { hovering in
                hoveredCharacter = hovering ? item.id : nil
            }
            .onTapGesture {
                characterListVM.selectCharacter(item.entry)
                if let filename = item.chatFilename {
                    appState.currentChat = try? appState.chatStorage.loadChat(
                        characterName: item.entry.card.data.name,
                        filename: filename
                    )
                    appState.saveActiveChatFilename()
                }
            }
            .contextMenu {
                Button("Edit Character") {
                    characterListVM.editCharacter(item.entry)
                }
                Button("Export Character") {
                    characterListVM.exportCharacter(item.entry)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    characterListVM.requestDeleteCharacter(item.entry)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func characterConversationRow(entry: CharacterEntry) -> some View {
        ConversationRowView(
            entry: entry,
            lastMessageDate: lastChatDate(for: entry),
            isSelected: appState.selectedSidebarItem == .character(entry.filename),
            isHovered: hoveredCharacter == entry.filename
        )
        .onHover { hovering in
            hoveredCharacter = hovering ? entry.filename : nil
        }
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
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.top, topPadding)
            .padding(.bottom, 2)
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        VStack(spacing: 0) {
            sidebarNavButton("Characters", icon: "person.text.rectangle", item: .characters)
            sidebarNavButton("World Lore", icon: "globe", item: .worldLore)
            sidebarNavButton("Personas", icon: "person.circle", item: .personas)

            Divider()
                .padding(.vertical, 2)

            sidebarNavButton("Settings", icon: "gear", item: .settings)
        }
        .padding(.vertical, 4)
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
            .padding(.leading, 4)
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

    struct IndividualConversationItem: Identifiable {
        let id: String
        let entry: CharacterEntry
        let chatFilename: String?
        let chatDate: Date?
    }

    private var individualConversations: [IndividualConversationItem] {
        var items: [IndividualConversationItem] = []
        for entry in filteredConversations {
            let charName = entry.card.data.name
            if let chats = try? appState.chatStorage.listChats(for: charName), !chats.isEmpty {
                for chat in chats {
                    items.append(IndividualConversationItem(
                        id: "\(entry.filename)_\(chat.filename)",
                        entry: entry,
                        chatFilename: chat.filename,
                        chatDate: chat.date
                    ))
                }
            } else {
                items.append(IndividualConversationItem(
                    id: entry.filename,
                    entry: entry,
                    chatFilename: nil,
                    chatDate: nil
                ))
            }
        }
        return items.sorted { ($0.chatDate ?? .distantPast) > ($1.chatDate ?? .distantPast) }
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
    var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            AvatarImageView(imageData: entry.avatarData, name: entry.card.data.name, size: AvatarImageView.sizeMedium)

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
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}

/// A row showing a specific conversation for a character
private struct IndividualConversationRowView: View {
    let item: SidebarView.IndividualConversationItem
    let isSelected: Bool
    var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            AvatarImageView(imageData: item.entry.avatarData, name: item.entry.card.data.name, size: AvatarImageView.sizeMedium)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.entry.card.data.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if let date = item.chatDate {
                    Text(date.relativeDisplayString)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("New conversation")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
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
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}
