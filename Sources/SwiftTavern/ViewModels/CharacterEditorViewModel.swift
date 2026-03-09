import Foundation
import SwiftUI
import AppKit

/// ViewModel for creating and editing characters
@Observable
final class CharacterEditorViewModel {
    var name = ""
    var description = ""
    var personality = ""
    var scenario = ""
    var firstMes = ""
    var mesExample = ""
    var creatorNotes = ""
    var systemPrompt = ""
    var postHistoryInstructions = ""
    var tags = ""
    var creator = ""
    var alternateGreetings: [String] = []
    var avatarData: Data?
    var showingAvatarPicker = false

    var isEditing: Bool
    var originalFilename: String?
    var errorMessage: String?

    private weak var appState: AppState?

    init(appState: AppState, character: CharacterEntry? = nil) {
        self.appState = appState
        self.isEditing = character != nil

        if let char = character {
            let data = char.card.data
            self.name = data.name
            self.description = data.description
            self.personality = data.personality
            self.scenario = data.scenario
            self.firstMes = data.firstMes
            self.mesExample = data.mesExample
            self.creatorNotes = data.creatorNotes
            self.systemPrompt = data.systemPrompt
            self.postHistoryInstructions = data.postHistoryInstructions
            self.tags = data.tags.joined(separator: ", ")
            self.creator = data.creator
            self.alternateGreetings = data.alternateGreetings
            self.avatarData = char.avatarData
            self.originalFilename = char.filename
        }
    }

    func pickAvatar() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            if let data = try? Data(contentsOf: url) {
                DispatchQueue.main.async {
                    self?.avatarData = data
                }
            }
        }
    }

    func removeAvatar() {
        avatarData = nil
    }

    func save() -> Bool {
        guard let appState, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Character name is required"
            return false
        }

        let charData = CharacterData(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            personality: personality,
            scenario: scenario,
            firstMes: firstMes,
            mesExample: mesExample,
            creatorNotes: creatorNotes,
            systemPrompt: systemPrompt,
            postHistoryInstructions: postHistoryInstructions,
            alternateGreetings: alternateGreetings,
            tags: tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            creator: creator
        )

        let card = TavernCardV2(data: charData)

        do {
            let filename = try appState.characterStorage.save(
                card: card,
                avatarData: avatarData,
                filename: originalFilename
            )

            // Reload characters
            appState.characters = (try? appState.characterStorage.loadAll()) ?? []

            // Select the saved character
            if let entry = appState.characters.first(where: { $0.filename == filename }) {
                appState.selectedCharacter = entry
            }

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
