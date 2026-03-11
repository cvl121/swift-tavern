import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// ViewModel for user persona management
@Observable
final class PersonaViewModel {
    var editingName = ""
    var editingDescription = ""
    var editingAvatarData: Data?
    var selectedPersona: Persona?
    var showingImporter = false
    var errorMessage: String?
    var showDeleteConfirmation = false
    var pendingDeletePersona: Persona?

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

    func updatePersona(_ persona: Persona, name: String, description: String) {
        guard let appState else { return }
        guard let idx = appState.personas.firstIndex(where: { $0.name == persona.name }) else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // If renaming, check for duplicates
        if trimmedName != persona.name && appState.personas.contains(where: { $0.name == trimmedName }) {
            return
        }

        // Update active userName if this persona was active
        if appState.settings.userName == persona.name {
            appState.settings.userName = trimmedName
            appState.saveSettings()
        }

        appState.personas[idx].name = trimmedName
        appState.personas[idx].description = description
        try? appState.personaStorage.saveAll(appState.personas)

        // Update selectedPersona to reflect changes
        selectedPersona = appState.personas[idx]
    }

    func requestDeletePersona(_ persona: Persona) {
        pendingDeletePersona = persona
        showDeleteConfirmation = true
    }

    func confirmDeletePersona() {
        guard let persona = pendingDeletePersona else {
            showDeleteConfirmation = false
            return
        }
        deletePersona(persona)
        if selectedPersona?.name == persona.name {
            selectedPersona = nil
        }
        showDeleteConfirmation = false
        pendingDeletePersona = nil
    }

    func deletePersona(_ persona: Persona) {
        guard let appState else { return }
        appState.personas.removeAll { $0.name == persona.name }
        try? appState.personaStorage.saveAll(appState.personas)
    }

    func isActivePersona(name: String) -> Bool {
        appState?.settings.userName == name
    }

    func selectAsActive(_ persona: Persona) {
        guard let appState else { return }
        appState.settings.userName = persona.name
        appState.saveSettings()
    }

    func exportAllPersonas() {
        guard let appState else { return }
        let panel = NSSavePanel()
        panel.title = "Export All Personas"
        panel.nameFieldStringValue = "personas.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(appState.personas)
            try data.write(to: url, options: .atomic)
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
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
