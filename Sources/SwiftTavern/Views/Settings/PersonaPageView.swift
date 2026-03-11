import SwiftUI

/// Full-page Personas view shown in the detail pane
struct PersonaPageView: View {
    @Bindable var personaVM: PersonaViewModel

    @State private var hoveredPersona: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Personas")
                    .font(.title2.bold())

                Spacer()

                Button(action: { personaVM.showingImporter = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { personaVM.exportAllPersonas() }) {
                    Label("Export All", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            if personaVM.personas.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No personas yet")
                        .foregroundColor(.secondary)
                    Text("Create a persona to set your identity in conversations.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                HStack(spacing: 0) {
                    // Persona list
                    VStack(spacing: 0) {
                        List(personaVM.personas) { persona in
                            personaRow(persona)
                                .listRowBackground(
                                    personaVM.selectedPersona?.name == persona.name
                                        ? Color.accentColor.opacity(0.15)
                                        : hoveredPersona == persona.name
                                            ? Color.primary.opacity(0.04)
                                            : Color.clear
                                )
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)

                        Divider()

                        // New persona button
                        newPersonaSection
                    }
                    .frame(width: 240)

                    Divider()

                    // Detail editor
                    if let persona = personaVM.selectedPersona {
                        PersonaDetailView(personaVM: personaVM, persona: persona)
                            .id(persona.name)
                    } else {
                        Text("Select a persona to view details")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $personaVM.showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                personaVM.importPersonas(from: url)
            }
        }
        .alert("Delete Persona", isPresented: $personaVM.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                personaVM.pendingDeletePersona = nil
            }
            Button("Delete", role: .destructive) {
                personaVM.confirmDeletePersona()
            }
        } message: {
            Text("Are you sure you want to delete \"\(personaVM.pendingDeletePersona?.name ?? "")\"? This cannot be undone.")
        }
    }

    private func personaRow(_ persona: Persona) -> some View {
        HStack(spacing: 8) {
            AvatarImageView(
                imageData: personaVM.loadAvatarData(for: persona),
                name: persona.name,
                size: AvatarImageView.sizeSmall
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(persona.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if personaVM.isActivePersona(name: persona.name) {
                        Text("Active")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor)
                            .cornerRadius(3)
                    }
                }
                if !persona.description.isEmpty {
                    Text(persona.description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            personaVM.selectedPersona = persona
        }
        .onHover { hovering in
            hoveredPersona = hovering ? persona.name : nil
        }
        .contextMenu {
            Button("Set Active") {
                personaVM.selectAsActive(persona)
            }
            Divider()
            Button("Delete", role: .destructive) {
                personaVM.requestDeletePersona(persona)
            }
        }
    }

    private var newPersonaSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarImageView(
                        imageData: personaVM.editingAvatarData,
                        name: personaVM.editingName.isEmpty ? "?" : personaVM.editingName,
                        size: AvatarImageView.sizeMedium
                    )
                    Button(action: { personaVM.pickAvatar() }) {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 4) {
                    TextField("Name", text: Binding(
                        get: { personaVM.editingName },
                        set: { personaVM.editingName = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                }
            }

            Button("Create Persona") {
                personaVM.createPersona()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .disabled(personaVM.editingName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(10)
    }
}

/// Detail editor view for a selected persona
private struct PersonaDetailView: View {
    var personaVM: PersonaViewModel
    let persona: Persona

    @State private var editName: String
    @State private var editDescription: String
    @State private var hasChanges = false

    init(personaVM: PersonaViewModel, persona: Persona) {
        self.personaVM = personaVM
        self.persona = persona
        _editName = State(initialValue: persona.name)
        _editDescription = State(initialValue: persona.description)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Avatar and name header
                HStack(spacing: 16) {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarImageView(
                            imageData: personaVM.loadAvatarData(for: persona),
                            name: persona.name,
                            size: AvatarImageView.sizeLarge
                        )
                        Button(action: { personaVM.pickAvatarForExisting(persona) }) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Change Avatar")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(persona.name)
                            .font(.title3.bold())
                        if personaVM.isActivePersona(name: persona.name) {
                            Text("Currently Active")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        if !personaVM.isActivePersona(name: persona.name) {
                            Button("Set Active") {
                                personaVM.selectAsActive(persona)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        Button(role: .destructive) {
                            personaVM.requestDeletePersona(persona)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Divider()

                // Editable fields
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("Persona name", text: $editName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: editName) { _, _ in hasChanges = true }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextEditor(text: $editDescription)
                        .font(.system(size: 13))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(.separatorColor), lineWidth: 1)
                        )
                        .onChange(of: editDescription) { _, _ in hasChanges = true }
                    Text("This description is sent to the AI as context about who you are.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                if hasChanges {
                    HStack {
                        Spacer()
                        Button("Save Changes") {
                            personaVM.updatePersona(persona, name: editName, description: editDescription)
                            hasChanges = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
