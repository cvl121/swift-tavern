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

    // Import preview
    var showingImportPreview = false
    var pendingImportURL: URL?
    var pendingImportCard: TavernCardV2?
    var pendingImportAvatarData: Data?

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
        do {
            try appState.characterStorage.delete(filename: entry.filename)
            appState.characters.removeAll { $0.filename == entry.filename }
            if appState.selectedCharacter?.filename == entry.filename {
                appState.setActiveCharacter(nil)
                appState.currentChat = nil
            }
        } catch {
            appState.showToast("Failed to delete character: \(error.localizedDescription)", isError: true)
        }
        showDeleteConfirmation = false
        pendingDeleteEntry = nil
    }

    /// Preview a character before importing — parses the file and shows a preview sheet
    func previewImport(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)

            if url.pathExtension.lowercased() == "png" {
                // Try to parse as PNG with embedded card
                let card = try CharacterCardParser.parse(from: data)
                pendingImportCard = card
                pendingImportAvatarData = data
            } else {
                // JSON import — try to decode as TavernCardV2
                let card = try JSONDecoder().decode(TavernCardV2.self, from: data)
                pendingImportCard = card
                pendingImportAvatarData = nil
            }
            pendingImportURL = url
            showingImportPreview = true
        } catch {
            // If preview parsing fails, fall through to direct import
            importCharacter(from: url)
        }
    }

    /// Confirm import after preview
    func confirmImport() {
        guard let url = pendingImportURL else {
            dismissImportPreview()
            return
        }
        importCharacter(from: url)
        dismissImportPreview()
    }

    /// Dismiss the import preview without importing
    func dismissImportPreview() {
        showingImportPreview = false
        pendingImportURL = nil
        pendingImportCard = nil
        pendingImportAvatarData = nil
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
        var exported = 0
        var failed = 0
        for entry in appState.characters {
            let src = appState.directoryManager.charactersDirectory.appendingPathComponent(entry.filename)
            let dst = baseURL.appendingPathComponent(entry.filename)
            if !fm.fileExists(atPath: dst.path) {
                do {
                    try fm.copyItem(at: src, to: dst)
                    exported += 1
                } catch {
                    failed += 1
                }
            } else {
                exported += 1 // already exists
            }
        }
        if failed > 0 {
            appState.showToast("Exported \(exported) characters, \(failed) failed", isError: true)
        } else {
            appState.showToast("Exported \(exported) characters")
        }
    }

    func selectCharacter(_ entry: CharacterEntry) {
        guard let appState else { return }
        appState.setActiveCharacter(entry)
        appState.selectedSidebarItem = .character(entry.filename)
        appState.selectedGroup = nil

        let charName = entry.card.data.name

        // Try to restore the previously active chat for this character
        if let activeChatFilename = appState.settings.activeChatPerCharacter[entry.filename] {
            do {
                appState.currentChat = try appState.chatStorage.loadChat(characterName: charName, filename: activeChatFilename)
                appState.saveActiveChatFilename()
                return
            } catch {
                // Active chat failed, fall through to most recent
            }
        }

        do {
            let chats = try appState.chatStorage.listChats(for: charName)
            if let mostRecent = chats.first {
                appState.currentChat = try appState.chatStorage.loadChat(
                    characterName: charName,
                    filename: mostRecent.filename
                )
            } else {
                appState.currentChat = try appState.chatStorage.createChat(
                    characterName: charName,
                    userName: appState.settings.userName,
                    firstMessage: entry.card.data.firstMes
                )
            }
        } catch {
            // Last resort: create a new chat
            do {
                appState.currentChat = try appState.chatStorage.createChat(
                    characterName: charName,
                    userName: appState.settings.userName,
                    firstMessage: entry.card.data.firstMes
                )
            } catch {
                appState.showToast("Failed to load or create chat: \(error.localizedDescription)", isError: true)
            }
        }
        appState.saveActiveChatFilename()
    }

    func startNewChat(_ entry: CharacterEntry) {
        guard let appState else { return }
        appState.setActiveCharacter(entry)
        appState.selectedSidebarItem = .character(entry.filename)
        appState.selectedGroup = nil

        do {
            appState.currentChat = try appState.chatStorage.createChat(
                characterName: entry.card.data.name,
                userName: appState.settings.userName,
                firstMessage: entry.card.data.firstMes
            )
        } catch {
            appState.showToast("Failed to create chat: \(error.localizedDescription)", isError: true)
        }
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
