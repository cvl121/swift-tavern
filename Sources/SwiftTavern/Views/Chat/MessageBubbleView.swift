import SwiftUI

/// Display a single chat message with avatar and context menu
struct MessageBubbleView: View {
    let message: ChatMessage
    let avatarData: Data?
    let index: Int
    let isEditing: Bool
    @Binding var editText: String
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onSaveEdit: () -> Void
    let onCancelEdit: () -> Void
    let onDelete: () -> Void
    let onRegenerate: (() -> Void)?
    let onDeleteAndAfter: (() -> Void)?
    var chatStyle: ChatStyle?

    // Swipe support (greeting or response swipes)
    var swipeInfo: SwipeInfo?

    struct SwipeInfo {
        let currentIndex: Int
        let totalCount: Int
        let canSwipeLeft: Bool
        let canSwipeRight: Bool
        let onSwipeLeft: () -> Void
        let onSwipeRight: () -> Void
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !message.isUser {
                AvatarImageView(imageData: avatarData, name: message.name, size: 32)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Name and timestamp
                HStack {
                    Text(message.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    if let date = message.sendDate.sillyTavernDate {
                        Text(date.relativeDisplayString)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }

                // Message content or edit field
                if isEditing {
                    VStack(spacing: 6) {
                        TextEditor(text: $editText)
                            .font(.system(size: 13))
                            .frame(minHeight: 60, maxHeight: 200)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 2))

                        HStack {
                            Button("Cancel", action: onCancelEdit)
                                .controlSize(.small)
                            Button("Save", action: onSaveEdit)
                                .controlSize(.small)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    MarkdownTextView(text: message.mes, chatStyle: chatStyle)
                        .font(.system(size: chatStyle?.fontSize ?? 13))
                        .padding(10)
                        .background(message.isUser ? Color.accentColor.opacity(0.15) : Color(.controlBackgroundColor))
                        .cornerRadius(12)
                }

                // Swipe arrows (greeting or response swipes)
                if let info = swipeInfo {
                    HStack(spacing: 8) {
                        Button(action: info.onSwipeLeft) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.borderless)
                        .disabled(!info.canSwipeLeft)

                        Text("\(info.currentIndex + 1)/\(info.totalCount)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        Button(action: info.onSwipeRight) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.borderless)
                        .disabled(!info.canSwipeRight)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)

            if message.isUser {
                AvatarImageView(imageData: nil, name: message.name, size: 32)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copy") { onCopy() }
                .keyboardShortcut("c", modifiers: .command)
            Button("Edit") { onEdit() }
            Divider()
            if let onRegenerate, !message.isUser {
                Button("Regenerate") { onRegenerate() }
            }
            if let onDeleteAndAfter {
                Button("Delete From Here") { onDeleteAndAfter() }
            }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
