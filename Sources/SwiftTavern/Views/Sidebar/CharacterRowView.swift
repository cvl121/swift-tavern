import SwiftUI

/// A single row in the character list sidebar
struct CharacterRowView: View {
    let entry: CharacterEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            AvatarImageView(imageData: entry.avatarData, name: entry.card.data.name, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.card.data.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if !entry.card.data.tags.isEmpty {
                    Text(entry.card.data.tags.prefix(3).joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}
