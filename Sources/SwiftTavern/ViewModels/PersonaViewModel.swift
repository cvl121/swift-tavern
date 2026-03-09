import Foundation
import SwiftUI
import AppKit

/// ViewModel for user persona management
@Observable
final class PersonaViewModel {
    var editingName = ""
    var editingDescription = ""
    var editingAvatarData: Data?
    var selectedPersona: Persona?
    var showingImporter = false
    var errorMessage: String?

    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    var personas: [Persona] {
        appState?.personas ?? []
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
                    self?.editingAvatarData = data
                }
            }
        }
    }

    func pickAvatarForExisting(_ persona: Persona) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard let self, let appState = self.appState else { return }
            guard response == .OK, let url = panel.url else { return }
            if let data = try? Data(contentsOf: url) {
                DispatchQueue.main.async {
                    if let idx = appState.personas.firstIndex(where: { $0.name == persona.name }) {
                        appState.personas[idx].avatarFilename = try? appState.personaStorage.saveAvatar(data, for: persona.name)
                        try? appState.personaStorage.saveAll(appState.personas)
                    }
                }
            }
        }
    }

    func loadAvatarData(for persona: Persona) -> Data? {
        guard let appState, let filename = persona.avatarFilename else { return nil }
        return appState.personaStorage.loadAvatar(filename: filename)
    }

    func createPersona() {
        guard let appState, !editingName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        var persona = Persona(
            name: editingName.trimmingCharacters(in: .whitespaces),
            description: editingDescription
        )

        if let avatarData = editingAvatarData {
            persona.avatarFilename = try? appState.personaStorage.saveAvatar(avatarData, for: persona.name)
        }

        appState.personas.append(persona)
        try? appState.personaStorage.saveAll(appState.personas)

        editingName = ""
        editingDescription = ""
        editingAvatarData = nil
    }

    func deletePersona(_ persona: Persona) {
        guard let appState else { return }
        appState.personas.removeAll { $0.name == persona.name }
        try? appState.personaStorage.saveAll(appState.personas)
    }

    func selectAsActive(_ persona: Persona) {
        guard let appState else { return }
        appState.settings.userName = persona.name
        appState.saveSettings()
    }

    func importPersonas(from url: URL) {
        guard let appState else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let imported = try JSONDecoder().decode([Persona].self, from: data)
            for persona in imported where !appState.personas.contains(where: { $0.name == persona.name }) {
                appState.personas.append(persona)
            }
            try? appState.personaStorage.saveAll(appState.personas)
        } catch {
            errorMessage = "Failed to import: \(error.localizedDescription)"
        }
    }
}
