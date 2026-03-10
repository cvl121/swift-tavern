import SwiftUI
import UniformTypeIdentifiers

/// Full character list view shown in the detail pane when "Characters" is selected in the sidebar
struct CharacterListView: View {
    @Bindable var appState: AppState
    @Bindable var characterListVM: CharacterListViewModel

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

                Button(action: { characterListVM.exportAllCharacters() }) {
                    Label("Export All", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: {
                    appState.selectedSidebarItem = .newCharacter
                }) {
                    Label("New Character", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

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
                                onSelect: {
                                    appState.selectedSidebarItem = .characterInfo(entry.filename)
                                },
                                onNewChat: { characterListVM.startNewChat(entry) },
                                onDelete: { characterListVM.requestDeleteCharacter(entry) }
                            )
                        }
                    }
                    .padding(16)
                }
                .onDrop(of: [.png, .json, .fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                }
            }
        }
    }
}

/// A row in the character list view showing character info with action buttons
private struct CharacterListRow: View {
    let entry: CharacterEntry
    let onSelect: () -> Void
    let onNewChat: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AvatarImageView(imageData: entry.avatarData, name: entry.card.data.name, size: AvatarImageView.sizeLarge)

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

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete Character")
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
