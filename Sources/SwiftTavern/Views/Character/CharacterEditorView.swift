import SwiftUI

/// Form for creating and editing character cards
struct CharacterEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: CharacterEditorViewModel
    var onDelete: (() -> Void)?

    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Avatar section with upload
                HStack(spacing: 16) {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarImageView(
                            imageData: viewModel.avatarData,
                            name: viewModel.name.isEmpty ? "?" : viewModel.name,
                            size: 80
                        )
                        .onTapGesture {
                            viewModel.pickAvatar()
                        }
                        .help("Click to upload avatar")

                        Button(action: { viewModel.pickAvatar() }) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                                .background(Circle().fill(Color(.controlBackgroundColor)).frame(width: 22, height: 22))
                        }
                        .buttonStyle(.plain)
                        .help("Upload Avatar")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.isEditing ? "Edit Character" : "New Character")
                            .font(.title2)
                        Text("Create a character card compatible with TavernCardV2 format")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if viewModel.avatarData != nil {
                            Button("Remove Avatar", role: .destructive) {
                                viewModel.removeAvatar()
                            }
                            .controlSize(.small)
                        }
                    }

                    Spacer()
                }

                // Form fields
                Group {
                    fieldSection("Name *", text: $viewModel.name)
                    fieldSection("Description", text: $viewModel.description, multiline: true)
                    fieldSection("Personality", text: $viewModel.personality, multiline: true)
                    fieldSection("Scenario", text: $viewModel.scenario, multiline: true)
                    fieldSection("First Message", text: $viewModel.firstMes, multiline: true)
                    fieldSection("Example Messages", text: $viewModel.mesExample, multiline: true,
                               helpText: "Format: <START>\\n{{user}}: message\\n{{char}}: response")
                }

                Group {
                    fieldSection("System Prompt", text: $viewModel.systemPrompt, multiline: true)
                    fieldSection("Post-History Instructions", text: $viewModel.postHistoryInstructions, multiline: true)
                    fieldSection("Creator Notes", text: $viewModel.creatorNotes, multiline: true)
                    fieldSection("Tags (comma-separated)", text: $viewModel.tags)
                    fieldSection("Creator", text: $viewModel.creator)
                }

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                // Action buttons
                HStack {
                    // Delete button (only when editing an existing character)
                    if viewModel.isEditing, let onDelete {
                        Button("Delete Character", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }

                    Spacer()

                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button(viewModel.isEditing ? "Save" : "Create") {
                        if viewModel.save() {
                            dismiss()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 480, idealWidth: 520, maxWidth: 600, minHeight: 500, idealHeight: 600, maxHeight: 700)
        .alert("Delete Character", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \"\(viewModel.name)\"? This cannot be undone.")
        }
    }

    @ViewBuilder
    private func fieldSection(_ title: String, text: Binding<String>, multiline: Bool = false, helpText: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            if multiline {
                TextEditor(text: text)
                    .font(.system(size: 13))
                    .frame(minHeight: 60, maxHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
            } else {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
            }

            if let help = helpText {
                Text(help)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}
