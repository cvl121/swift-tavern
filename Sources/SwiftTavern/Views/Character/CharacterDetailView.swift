import SwiftUI

/// Read-only character info display
struct CharacterDetailView: View {
    let entry: CharacterEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 16) {
                    AvatarImageView(imageData: entry.avatarData, name: entry.card.data.name, size: 80)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.card.data.name)
                            .font(.title)
                        if !entry.card.data.creator.isEmpty {
                            Text("by \(entry.card.data.creator)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if !entry.card.data.tags.isEmpty {
                            Text(entry.card.data.tags.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }

                if !entry.card.data.description.isEmpty {
                    infoSection("Description", entry.card.data.description)
                }
                if !entry.card.data.personality.isEmpty {
                    infoSection("Personality", entry.card.data.personality)
                }
                if !entry.card.data.scenario.isEmpty {
                    infoSection("Scenario", entry.card.data.scenario)
                }
                if !entry.card.data.firstMes.isEmpty {
                    infoSection("First Message", entry.card.data.firstMes)
                }
                if !entry.card.data.creatorNotes.isEmpty {
                    infoSection("Creator Notes", entry.card.data.creatorNotes)
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func infoSection(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Text(content)
                .font(.system(size: 13))
                .textSelection(.enabled)
        }
    }
}
