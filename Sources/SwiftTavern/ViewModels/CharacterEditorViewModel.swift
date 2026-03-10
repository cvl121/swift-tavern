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
    var selectedWorldLore: String?

    var isEditing: Bool
    var originalFilename: String?
    var errorMessage: String?

    // Original values for change tracking
    private var originalName: String
    private var originalDescription: String
    private var originalPersonality: String
    private var originalScenario: String
    private var originalFirstMes: String
    private var originalMesExample: String
    private var originalCreatorNotes: String
    private var originalSystemPrompt: String
    private var originalPostHistoryInstructions: String
    private var originalTags: String
    private var originalCreator: String
    private var originalAlternateGreetings: [String]
    private var originalAvatarData: Data?
    private var originalWorldLore: String?

    var hasUnsavedChanges: Bool {
        if isEditing {
            return name != originalName ||
                description != originalDescription ||
                personality != originalPersonality ||
                scenario != originalScenario ||
                firstMes != originalFirstMes ||
                mesExample != originalMesExample ||
                creatorNotes != originalCreatorNotes ||
                systemPrompt != originalSystemPrompt ||
                postHistoryInstructions != originalPostHistoryInstructions ||
                tags != originalTags ||
                creator != originalCreator ||
                alternateGreetings != originalAlternateGreetings ||
                avatarData != originalAvatarData ||
                selectedWorldLore != originalWorldLore
        } else {
            // New character: any non-empty field means unsaved changes
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !description.isEmpty ||
                !personality.isEmpty ||
                !scenario.isEmpty ||
                !firstMes.isEmpty ||
                !mesExample.isEmpty ||
                !creatorNotes.isEmpty ||
                !systemPrompt.isEmpty ||
                !postHistoryInstructions.isEmpty ||
                !tags.isEmpty ||
                !creator.isEmpty ||
                !alternateGreetings.isEmpty ||
                avatarData != nil
        }
    }

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
            self.selectedWorldLore = (data.extensions?["swifttavern_world_lore"]?.value as? String)

            // Store originals
            self.originalName = data.name
            self.originalDescription = data.description
            self.originalPersonality = data.personality
            self.originalScenario = data.scenario
            self.originalFirstMes = data.firstMes
            self.originalMesExample = data.mesExample
            self.originalCreatorNotes = data.creatorNotes
            self.originalSystemPrompt = data.systemPrompt
            self.originalPostHistoryInstructions = data.postHistoryInstructions
            self.originalTags = data.tags.joined(separator: ", ")
            self.originalCreator = data.creator
            self.originalAlternateGreetings = data.alternateGreetings
            self.originalAvatarData = char.avatarData
            self.originalWorldLore = self.selectedWorldLore
        } else {
            self.originalName = ""
            self.originalDescription = ""
            self.originalPersonality = ""
            self.originalScenario = ""
            self.originalFirstMes = ""
            self.originalMesExample = ""
            self.originalCreatorNotes = ""
            self.originalSystemPrompt = ""
            self.originalPostHistoryInstructions = ""
            self.originalTags = ""
            self.originalCreator = ""
            self.originalAlternateGreetings = []
            self.originalAvatarData = nil
            self.originalWorldLore = nil
        }
    }

    var worldInfoBookNames: [String] {
        appState?.worldInfoBooks.map(\.name) ?? []
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

        var extensions: [String: AnyCodable]? = nil
        if let worldLore = selectedWorldLore {
            extensions = ["swifttavern_world_lore": AnyCodable(worldLore)]
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
            creator: creator,
            extensions: extensions
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
