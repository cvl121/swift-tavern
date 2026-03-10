import Foundation
import SwiftUI
import AppKit

/// ViewModel for World Info management
@Observable
final class WorldInfoViewModel {
    var selectedBook: WorldInfo?
    var showingNewBookDialog = false
    var newBookName = ""
    var showingImporter = false
    var errorMessage: String?

    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    var books: [WorldInfo] {
        appState?.worldInfoBooks ?? []
    }

    /// The global world lore name from settings
    var globalWorldLoreName: String? {
        appState?.settings.globalWorldLore
    }

    /// The per-character world lore name for the currently selected character
    var characterWorldLoreName: String? {
        appState?.selectedCharacter?.card.data.extensions?["swifttavern_world_lore"]?.value as? String
    }

    /// The effective active world lore name (character override > global)
    var activeWorldLoreName: String? {
        characterWorldLoreName ?? globalWorldLoreName
    }

    /// The currently selected character name (for display)
    var selectedCharacterName: String? {
        appState?.selectedCharacter?.card.data.name
    }

    func createBook() {
        guard let appState, !newBookName.isEmpty else { return }
        let book = WorldInfo(name: newBookName)
        do {
            try appState.worldInfoStorage.save(book)
            appState.worldInfoBooks.append(book)
            selectedBook = book
            newBookName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteBook(_ book: WorldInfo) {
        guard let appState else { return }
        try? appState.worldInfoStorage.delete(name: book.name)
        appState.worldInfoBooks.removeAll { $0.name == book.name }
        if selectedBook?.name == book.name {
            selectedBook = nil
        }
    }

    func addEntry(to book: inout WorldInfo) {
        let nextUID = (book.entries.values.map(\.uid).max() ?? -1) + 1
        let entry = WorldInfoEntry(uid: nextUID)
        book.entries[String(nextUID)] = entry
        saveBook(book)
    }

    func removeEntry(uid: Int, from book: inout WorldInfo) {
        book.entries.removeValue(forKey: String(uid))
        saveBook(book)
    }

    func saveBook(_ book: WorldInfo) {
        guard let appState else { return }
        do {
            try appState.worldInfoStorage.save(book)
            if let idx = appState.worldInfoBooks.firstIndex(where: { $0.name == book.name }) {
                appState.worldInfoBooks[idx] = book
            }
            selectedBook = book
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportBook(_ book: WorldInfo) {
        let panel = NSSavePanel()
        panel.title = "Export World Lore"
        panel.nameFieldStringValue = "\(book.name).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(book)
            try data.write(to: url, options: .atomic)
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func importWorldLore(from url: URL) {
        guard let appState else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let book = try appState.worldInfoStorage.loadWorldInfo(from: url)
            try appState.worldInfoStorage.save(book)
            appState.worldInfoBooks.append(book)
            selectedBook = book
        } catch {
            errorMessage = "Failed to import: \(error.localizedDescription)"
        }
    }
}
