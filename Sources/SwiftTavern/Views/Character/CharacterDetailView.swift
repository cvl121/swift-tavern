import SwiftUI

/// Read-only character info display
struct CharacterDetailView: View {
    let entry: CharacterEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    AvatarImageView(imageData: entry.avatarData, name: entry.card.data.name, size: 80)
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.card.data.name)
                            .font(.title.bold())
                        if !entry.card.data.creator.isEmpty {
                            Text("by \(entry.card.data.creator)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if !entry.card.data.tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(entry.card.data.tags.prefix(6), id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
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
            .padding(24)
        }
    }

    @ViewBuilder
    private func infoSection(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)
            Text(content)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.controlBackgroundColor).opacity(0.4))
                )
        }
    }
}
