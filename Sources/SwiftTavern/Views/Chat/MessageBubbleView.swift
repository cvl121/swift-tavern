import SwiftUI
import AppKit

/// Display a single chat message with avatar and action buttons
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
    var onToggleBookmark: (() -> Void)?
    var onFork: (() -> Void)?
    var chatStyle: ChatStyle?
    /// Base directory for resolving image URLs
    var imageBasePath: URL?
    /// How large images appear in the chat
    var imageDisplaySize: ImageDisplaySize = .medium
    /// Whether to show text labels next to action buttons
    var showActionLabels: Bool = false

    var isFocused: Bool = false

    @State private var isHovered = false

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
                    if message.isUser { Spacer() }

                    Text(message.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    if message.isBookmarked {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }

                    if let date = message.sendDate.chatDate {
                        Text(date.relativeDisplayString)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                // Message content or edit field
                if isEditing {
                    MessageEditField(
                        text: $editText,
                        onSave: onSaveEdit,
                        onCancel: onCancelEdit
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        MarkdownTextView(text: message.mes, chatStyle: chatStyle)
                            .font(.system(size: chatStyle?.fontSize ?? 13))
                            .textSelection(.enabled)

                        // Generated image (loaded via cache to avoid re-reading from disk)
                        if message.hasImage, let imageURL = message.imageURL,
                           let basePath = imageBasePath {
                            let imagePath = basePath.appendingPathComponent(imageURL)
                            let cacheKey = imageURL
                            if let nsImage = ImageCache.shared.image(for: cacheKey) ?? loadAndCacheImage(path: imagePath, key: cacheKey) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(
                                        maxWidth: imageDisplaySize.maxWidth,
                                        maxHeight: imageDisplaySize.maxHeight
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(message.isUser
                                ? Color.accentColor.opacity(0.08)
                                : Color(.controlBackgroundColor).opacity(0.5))
                    )

                    // Action buttons
                    messageActionButtons
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
                        .accessibilityLabel("Previous response")

                        Text("\(info.currentIndex + 1)/\(info.totalCount)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        Button(action: info.onSwipeRight) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.borderless)
                        .disabled(!info.canSwipeRight)
                        .accessibilityLabel("Next response")
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)

            if message.isUser {
                AvatarImageView(imageData: avatarData, name: message.name, size: 32)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isFocused ? Color.accentColor.opacity(0.06) : Color.clear)
        .overlay(
            Rectangle()
                .fill(Color(.separatorColor).opacity(0.3))
                .frame(height: 0.5),
            alignment: .bottom
        )
        .overlay(
            isFocused ? RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor.opacity(0.3), lineWidth: 1).padding(2) : nil
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var messageActionButtons: some View {
        HStack(spacing: showActionLabels ? 6 : 4) {
            actionButton("Copy", icon: "doc.on.doc", action: onCopy)
            actionButton("Edit", icon: "pencil", action: onEdit)
            actionButton(
                message.isBookmarked ? "Unbookmark" : "Bookmark",
                icon: message.isBookmarked ? "star.fill" : "star",
                action: onToggleBookmark ?? {},
                tint: message.isBookmarked ? .yellow : nil
            )

            if let onFork {
                actionButton("Fork", icon: "arrow.branch", action: onFork)
            }

            if let onRegenerate, !message.isUser {
                actionButton("Regenerate", icon: "arrow.clockwise", action: onRegenerate)
            }

            if let onDeleteAndAfter {
                actionButton("Delete After", icon: "scissors", action: onDeleteAndAfter)
            }

            actionButton("Delete", icon: "trash", action: onDelete, tint: .red)
        }
        .padding(.top, 2)
        .opacity(isHovered ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    /// Load a generated image from disk and cache it for future renders
    private func loadAndCacheImage(path: URL, key: String) -> NSImage? {
        guard let nsImage = NSImage(contentsOf: path) else { return nil }
        ImageCache.shared.setImage(nsImage, for: key)
        return nsImage
    }

    private func actionButton(_ label: String, icon: String, action: @escaping () -> Void, tint: Color? = nil) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                if showActionLabels {
                    Text(label)
                        .font(.system(size: 10))
                }
            }
            .foregroundColor(tint ?? .secondary)
            .padding(.horizontal, showActionLabels ? 6 : 4)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Editing field extracted to its own view so its TextEditor state is independent
/// of the LazyVStack recycling that causes hangs when scrolling during an edit.
private struct MessageEditField: View {
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var localText: String = ""

    var body: some View {
        VStack(spacing: 6) {
            TextEditor(text: $localText)
                .font(.system(size: 13))
                .frame(minHeight: 100, maxHeight: 500)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 2))

            HStack {
                Button("Cancel", action: onCancel)
                    .controlSize(.small)

                Button("Save") {
                    text = localText
                    onSave()
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            localText = text
        }
    }
}
