import SwiftUI

/// User persona management settings
struct PersonaSettingsView: View {
    let viewModel: PersonaViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("User Personas")
                .font(.headline)

            // Existing personas
            ForEach(viewModel.personas) { persona in
                HStack {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarImageView(
                            imageData: viewModel.loadAvatarData(for: persona),
                            name: persona.name,
                            size: 36
                        )

                        Button(action: { viewModel.pickAvatarForExisting(persona) }) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Change Avatar")
                    }

                    VStack(alignment: .leading) {
                        Text(persona.name)
                            .font(.system(size: 13, weight: .medium))
                        if !persona.description.isEmpty {
                            Text(persona.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Button("Set Active") {
                        viewModel.selectAsActive(persona)
                    }
                    .controlSize(.small)

                    Button(role: .destructive) {
                        viewModel.deletePersona(persona)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }

            Divider()

            // New persona form
            Text("New Persona")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarImageView(
                        imageData: viewModel.editingAvatarData,
                        name: viewModel.editingName.isEmpty ? "?" : viewModel.editingName,
                        size: 48
                    )

                    Button(action: { viewModel.pickAvatar() }) {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Upload Avatar")
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Name", text: Binding(
                        get: { viewModel.editingName },
                        set: { viewModel.editingName = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)

                    TextField("Description", text: Binding(
                        get: { viewModel.editingDescription },
                        set: { viewModel.editingDescription = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }

            Button("Create Persona") {
                viewModel.createPersona()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}
