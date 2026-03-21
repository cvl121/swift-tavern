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
    var imageBasePath: URL?
    var imageDisplaySize: ImageDisplaySize = .medium
    var showActionLabels: Bool = false
    var isFocused: Bool = false
    var swipeInfo: SwipeInfo?
    var searchHighlight: String?

    @State private var isHovered = false

    struct SwipeInfo {
        let currentIndex: Int
        let totalCount: Int
        let canSwipeLeft: Bool
        let canSwipeRight: Bool
        let onSwipeLeft: () -> Void
        let onSwipeRight: () -> Void
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !message.isUser {
                AvatarImageView(imageData: avatarData, name: message.name, size: 32)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 3) {
                // Name + timestamp
                HStack(spacing: 5) {
                    if message.isUser { Spacer() }
                    Text(message.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(message.isUser ? .accentColor.opacity(0.7) : .secondary)
                    if message.isBookmarked {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                    }
                    if let date = message.sendDate.chatDate {
                        Text(date.relativeDisplayString)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }

                // Content
                if isEditing {
                    MessageEditField(text: $editText, onSave: onSaveEdit, onCancel: onCancelEdit)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        MarkdownTextView(text: message.mes, chatStyle: chatStyle)
                            .font(.system(size: chatStyle?.fontSize ?? 13))
                            .textSelection(.enabled)

                        if message.hasImage, let imageURL = message.imageURL, let basePath = imageBasePath {
                            let imagePath = basePath.appendingPathComponent(imageURL)
                            if let nsImage = ImageCache.shared.image(for: imageURL) ?? loadAndCacheImage(path: imagePath, key: imageURL) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: imageDisplaySize.maxWidth, maxHeight: imageDisplaySize.maxHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(messageBubbleBackground)

                    // Action buttons (show on hover)
                    actionButtons
                }

                // Swipe controls
                if let info = swipeInfo {
                    swipeControls(info)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)

            if message.isUser {
                AvatarImageView(imageData: avatarData, name: message.name, size: 32)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            searchHighlight != nil
                ? Color.yellow.opacity(0.08)
                : isFocused ? Color.accentColor.opacity(0.03) : Color.clear
        )
        .overlay(alignment: .leading) {
            if searchHighlight != nil {
                Rectangle()
                    .fill(Color.yellow.opacity(0.6))
                    .frame(width: 3)
            }
        }
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.name): \(message.mes.prefix(200))")
    }

    // MARK: - Bubble Background

    private var messageBubbleBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(message.isUser
                ? Color.accentColor.opacity(0.07)
                : Color(.controlBackgroundColor).opacity(0.4))
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: showActionLabels ? 5 : 3) {
            actionBtn("Copy", icon: "doc.on.doc", action: onCopy)
            actionBtn("Edit", icon: "pencil", action: onEdit)
            actionBtn(
                message.isBookmarked ? "Unbookmark" : "Bookmark",
                icon: message.isBookmarked ? "star.fill" : "star",
                action: onToggleBookmark ?? {},
                tint: message.isBookmarked ? .yellow : nil
            )
            if let onFork { actionBtn("Fork", icon: "arrow.branch", action: onFork) }
            if let onRegenerate, !message.isUser {
                actionBtn("Regenerate", icon: "arrow.clockwise", action: onRegenerate)
            }
            if let onDeleteAndAfter { actionBtn("Delete After", icon: "scissors", action: onDeleteAndAfter) }
            actionBtn("Delete", icon: "trash", action: onDelete, tint: .red)
        }
        .padding(.top, 2)
        .opacity(isHovered ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private func actionBtn(_ label: String, icon: String, action: @escaping () -> Void, tint: Color? = nil) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 10))
                if showActionLabels { Text(label).font(.system(size: 10)) }
            }
            .foregroundColor(tint ?? .secondary)
            .padding(.horizontal, showActionLabels ? 6 : 5)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.04)))
            .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    // MARK: - Swipe Controls

    private func swipeControls(_ info: SwipeInfo) -> some View {
        HStack(spacing: 10) {
            Button(action: info.onSwipeLeft) {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless).disabled(!info.canSwipeLeft)
            .accessibilityLabel("Previous response")

            Text("\(info.currentIndex + 1)/\(info.totalCount)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary).monospacedDigit()
                .accessibilityLabel("Response \(info.currentIndex + 1) of \(info.totalCount)")

            Button(action: info.onSwipeRight) {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless).disabled(!info.canSwipeRight)
            .accessibilityLabel("Next response")
        }
        .padding(.top, 2)
    }

    private func loadAndCacheImage(path: URL, key: String) -> NSImage? {
        guard let nsImage = NSImage(contentsOf: path) else { return nil }
        ImageCache.shared.setImage(nsImage, for: key)
        return nsImage
    }
}

// MARK: - Message Edit Field

private struct MessageEditField: View {
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @State private var localText: String = ""

    var body: some View {
        VStack(spacing: 8) {
            TextEditor(text: $localText)
                .font(.system(size: 13))
                .frame(minHeight: 80, maxHeight: 400)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(.controlBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
                )

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .controlSize(.small)
                    .keyboardShortcut(.cancelAction)
                Button("Save") { text = localText; onSave() }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear { localText = text }
    }
}
