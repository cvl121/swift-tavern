import SwiftUI

/// Shows the current streaming text during generation
struct StreamingIndicatorView: View {
    let characterName: String
    let text: String
    let avatarData: Data?
    var chatStyle: ChatStyle?

    @State private var dotPhase = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarImageView(imageData: avatarData, name: characterName, size: 34)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
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
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.controlBackgroundColor).opacity(0.45))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separatorColor).opacity(0.2), lineWidth: 0.5)
                        )
                } else {
                    HStack(spacing: 5) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Color.secondary.opacity(dotPhase == i ? 0.8 : 0.3))
                                .frame(width: 6, height: 6)
                                .animation(.easeInOut(duration: 0.4).delay(Double(i) * 0.15), value: dotPhase)
                        }
                    }
                    .padding(12)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                            dotPhase = 2
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
