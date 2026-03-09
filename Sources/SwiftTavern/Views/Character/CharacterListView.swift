import SwiftUI

/// Full character list view shown in the detail pane when "Characters" is selected in the sidebar
struct CharacterListView: View {
    @Bindable var appState: AppState
    @Bindable var characterListVM: CharacterListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Characters")
                    .font(.title2.bold())

                Spacer()

                Button(action: { characterListVM.showingImporter = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { characterListVM.showingCreator = true }) {
                    Label("New Character", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(20)

            Divider()

            if appState.characters.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No characters yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Create or import a character to get started.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(characterListVM.filteredCharacters) { entry in
                            CharacterListRow(
                                entry: entry,
                                onEdit: { characterListVM.editCharacter(entry) },
                                onNewChat: { characterListVM.selectCharacter(entry) },
                                onDelete: { characterListVM.requestDeleteCharacter(entry) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

/// A row in the character list view showing character info with action buttons
private struct CharacterListRow: View {
    let entry: CharacterEntry
    let onEdit: () -> Void
    let onNewChat: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AvatarImageView(imageData: entry.avatarData, name: entry.card.data.name, size: 48)
                .onTapGesture(perform: onEdit)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.card.data.name)
                    .font(.system(size: 14, weight: .semibold))

                if !entry.card.data.description.isEmpty {
                    Text(entry.card.data.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if !entry.card.data.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.card.data.tags.prefix(4), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            Spacer()

            Button(action: onNewChat) {
                Label("Chat", systemImage: "bubble.left")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Start or resume chat")

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit Character")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete Character")
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}
