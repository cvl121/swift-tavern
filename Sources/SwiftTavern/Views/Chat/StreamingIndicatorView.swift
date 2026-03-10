import SwiftUI

/// Shows the current streaming text during generation
struct StreamingIndicatorView: View {
    let characterName: String
    let text: String
    let avatarData: Data?
    var chatStyle: ChatStyle?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarImageView(imageData: avatarData, name: characterName, size: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(characterName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }

                if !text.isEmpty {
                    MarkdownTextView(text: text, chatStyle: chatStyle)
                        .font(.system(size: chatStyle?.fontSize ?? 13))
                        .padding(12)
                } else {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 6, height: 6)
                                .opacity(0.5)
                        }
                    }
                    .padding(10)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
