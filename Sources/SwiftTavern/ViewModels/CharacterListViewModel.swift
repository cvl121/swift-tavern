import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// ViewModel for the character list sidebar
@Observable
final class CharacterListViewModel {
    var searchText = ""
    var showingImporter = false
    var showingExporter = false
    var exportDocument: PNGDocument?
    var exportFilename: String?
    var errorMessage: String?

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

    var showDeleteConfirmation = false
    var pendingDeleteEntry: CharacterEntry?

    func editCharacter(_ entry: CharacterEntry) {
        guard let appState else { return }
        appState.selectedSidebarItem = .characterInfo(entry.filename)
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
        do {
            let entry = try appState.characterStorage.importCharacter(from: url)
            // Replace existing entry with same filename to avoid duplicates
            if let existingIndex = appState.characters.firstIndex(where: { $0.filename == entry.filename }) {
                appState.characters[existingIndex] = entry
            } else {
                appState.characters.append(entry)
            }
            appState.characters.sort { $0.card.data.name.lowercased() < $1.card.data.name.lowercased() }
            errorMessage = nil
            appState.showToast("Character imported: \(entry.card.data.name)")
        } catch {
            errorMessage = "Failed to import character: \(error.localizedDescription)"
            appState.showToast("Failed to import character: \(error.localizedDescription)", isError: true)
        }
    }

    func exportCharacter(_ entry: CharacterEntry) {
        guard let appState else { return }
        let sourceURL = appState.directoryManager.charactersDirectory.appendingPathComponent(entry.filename)
        do {
            let data = try Data(contentsOf: sourceURL)
            exportDocument = PNGDocument(data: data)
            exportFilename = entry.filename
            showingExporter = true
        } catch {
            errorMessage = "Failed to export character: \(error.localizedDescription)"
        }
    }

    func exportAllCharacters() {
        guard let appState else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose Export Destination"
        panel.message = "Select a folder to export characters into"
        panel.prompt = "Export Here"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let baseURL = panel.url else { return }
        let fm = FileManager.default
        for entry in appState.characters {
            let src = appState.directoryManager.charactersDirectory.appendingPathComponent(entry.filename)
            let dst = baseURL.appendingPathComponent(entry.filename)
            if !fm.fileExists(atPath: dst.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }

    func selectCharacter(_ entry: CharacterEntry) {
        guard let appState else { return }
        appState.setActiveCharacter(entry)
        appState.selectedSidebarItem = .character(entry.filename)
        appState.selectedGroup = nil

        let charName = entry.card.data.name

        // Try to restore the previously active chat for this character
        if let activeChatFilename = appState.settings.activeChatPerCharacter[entry.filename],
           let session = try? appState.chatStorage.loadChat(characterName: charName, filename: activeChatFilename) {
            appState.currentChat = session
        } else if let chats = try? appState.chatStorage.listChats(for: charName),
                  let mostRecent = chats.first {
            appState.currentChat = try? appState.chatStorage.loadChat(
                characterName: charName,
                filename: mostRecent.filename
            )
        } else {
            appState.currentChat = try? appState.chatStorage.createChat(
                characterName: charName,
                userName: appState.settings.userName,
                firstMessage: entry.card.data.firstMes
            )
        }
        appState.saveActiveChatFilename()
    }

    func startNewChat(_ entry: CharacterEntry) {
        guard let appState else { return }
        appState.setActiveCharacter(entry)
        appState.selectedSidebarItem = .character(entry.filename)
        appState.selectedGroup = nil

        appState.currentChat = try? appState.chatStorage.createChat(
            characterName: entry.card.data.name,
            userName: appState.settings.userName,
            firstMessage: entry.card.data.firstMes
        )
        appState.saveActiveChatFilename()
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
