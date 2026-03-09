import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// ViewModel for the character list sidebar
@Observable
final class CharacterListViewModel {
    var searchText = ""
    var showingImporter = false
    var showingCreator = false
    var showingExporter = false
    var exportDocument: PNGDocument?
    var exportFilename: String?

    var filteredCharacters: [CharacterEntry] {
        guard let appState else { return [] }
        if searchText.isEmpty {
            return appState.characters
        }
        return appState.characters.filter {
            $0.card.data.name.localizedCaseInsensitiveContains(searchText) ||
            $0.card.data.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    var showingEditor = false
    var editingEntry: CharacterEntry?

    var showDeleteConfirmation = false
    var pendingDeleteEntry: CharacterEntry?

    func editCharacter(_ entry: CharacterEntry) {
        editingEntry = entry
        showingEditor = true
    }

    func requestDeleteCharacter(_ entry: CharacterEntry) {
        pendingDeleteEntry = entry
        showDeleteConfirmation = true
    }

    func confirmDeleteCharacter() {
        guard let appState, let entry = pendingDeleteEntry else {
            showDeleteConfirmation = false
            return
        }
        try? appState.characterStorage.delete(filename: entry.filename)
        appState.characters.removeAll { $0.filename == entry.filename }
        if appState.selectedCharacter?.filename == entry.filename {
            appState.setActiveCharacter(nil)
            appState.currentChat = nil
        }
        showDeleteConfirmation = false
        pendingDeleteEntry = nil
    }

    func importCharacter(from url: URL) {
        guard let appState else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if let entry = try? appState.characterStorage.importCharacter(from: url) {
            appState.characters.append(entry)
            appState.characters.sort { $0.card.data.name.lowercased() < $1.card.data.name.lowercased() }
        }
    }

    func exportCharacter(_ entry: CharacterEntry) {
        guard let appState else { return }
        let sourceURL = appState.directoryManager.charactersDirectory.appendingPathComponent(entry.filename)
        guard let data = try? Data(contentsOf: sourceURL) else { return }
        exportDocument = PNGDocument(data: data)
        exportFilename = entry.filename
        showingExporter = true
    }

    func selectCharacter(_ entry: CharacterEntry) {
        guard let appState else { return }
        appState.setActiveCharacter(entry)
        appState.selectedSidebarItem = .character(entry.filename)
        appState.selectedGroup = nil

        // Load most recent chat or create new one
        if let chats = try? appState.chatStorage.listChats(for: entry.card.data.name),
           let mostRecent = chats.first {
            appState.currentChat = try? appState.chatStorage.loadChat(
                characterName: entry.card.data.name,
                filename: mostRecent.filename
            )
        } else {
            appState.currentChat = try? appState.chatStorage.createChat(
                characterName: entry.card.data.name,
                userName: appState.settings.userName,
                firstMessage: entry.card.data.firstMes
            )
        }
    }
}

/// Document wrapper for PNG file export
struct PNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
