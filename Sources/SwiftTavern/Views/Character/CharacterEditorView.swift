import SwiftUI

/// Inline view for creating and editing character cards (replaces modal)
struct CharacterEditorView: View {
    @Bindable var viewModel: CharacterEditorViewModel
    var onDelete: (() -> Void)?
    var onBack: (() -> Void)?

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12))
                            Text("Back")
                                .font(.system(size: 13))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }

                Spacer()

                Text(viewModel.isEditing ? "Edit Character" : "New Character")
                    .font(.headline)

                Spacer()

                // Save button
                Button(viewModel.isEditing ? "Save" : "Create") {
                    if viewModel.save() {
                        onBack?()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Scrollable form
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
                            Text("TavernCardV2 format")
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

                        // World Lore association
                        VStack(alignment: .leading, spacing: 4) {
                            Text("World Lore")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            Picker("World Lore", selection: $viewModel.selectedWorldLore) {
                                Text("None (use global)").tag(String?.none)
                                ForEach(viewModel.worldInfoBookNames, id: \.self) { name in
                                    Text(name).tag(Optional(name))
                                }
                            }
                            .labelsHidden()
                            .fixedSize()

                            Text("Override the global world lore for this character. If set, only this book will be used in conversations.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    // Delete button (only when editing an existing character)
                    if viewModel.isEditing, onDelete != nil {
                        Divider()
                        Button("Delete Character", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }
                .padding(20)
            }
        }
        .alert("Delete Character", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                onBack?()
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
