import SwiftUI

/// Preview modal shown before confirming a character import
struct CharacterImportPreviewView: View {
    @Bindable var characterListVM: CharacterListViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import Character")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") { characterListVM.dismissImportPreview() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if let card = characterListVM.pendingImportCard {
                ScrollView {
                    VStack(spacing: 16) {
                        // Avatar + Name
                        HStack(spacing: 16) {
                            AvatarImageView(
                                imageData: characterListVM.pendingImportAvatarData,
                                name: card.data.name,
                                size: AvatarImageView.sizeXLarge
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.data.name)
                                    .font(.title3.bold())

                                if !card.data.tags.isEmpty {
                                    Text(card.data.tags.joined(separator: ", "))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                if !card.data.creator.isEmpty {
                                    Text("by \(card.data.creator)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }

                        // Description
                        if !card.data.description.isEmpty {
                            previewField("Description", text: card.data.description)
                        }

                        // Personality
                        if !card.data.personality.isEmpty {
                            previewField("Personality", text: card.data.personality)
                        }

                        // Scenario
                        if !card.data.scenario.isEmpty {
                            previewField("Scenario", text: card.data.scenario)
                        }

                        // First Message preview
                        if !card.data.firstMes.isEmpty {
                            previewField("First Message", text: card.data.firstMes)
                        }

                        // Stats
                        HStack(spacing: 16) {
                            statBadge("\(card.data.alternateGreetings.count)", label: "Alt Greetings")
                            if let book = card.data.characterBook {
                                statBadge("\(book.entries.count)", label: "Book Entries")
                            }
                            if !card.data.mesExample.isEmpty {
                                statBadge("Yes", label: "Examples")
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                }

                Divider()

                // Actions
                HStack {
                    Spacer()
                    Button("Cancel") { characterListVM.dismissImportPreview() }
                        .controlSize(.large)
                    Button("Import") { characterListVM.confirmImport() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                }
                .padding()
            } else {
                Text("Unable to preview character")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 500, height: 550)
    }

    private func previewField(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Text(text.prefix(500) + (text.count > 500 ? "..." : ""))
                .font(.system(size: 12))
                .foregroundColor(.primary.opacity(0.8))
                .lineLimit(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private func statBadge(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }
}
