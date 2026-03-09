import SwiftUI

/// Group chat view - extends the chat pattern for multiple characters
struct GroupChatView: View {
    @Bindable var appState: AppState
    @Bindable var groupChatVM: GroupChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Group header
            groupHeader

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(groupChatVM.messages.enumerated()), id: \.element.id) { index, message in
                            groupMessageBubble(index: index, message: message)
                                .id(message.id)
                        }

                        if groupChatVM.isGenerating {
                            StreamingIndicatorView(
                                characterName: "Generating...",
                                text: groupChatVM.streamingText,
                                avatarData: nil
                            )
                            .id("streaming")
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: groupChatVM.messages.count) {
                    withAnimation {
                        proxy.scrollTo(groupChatVM.messages.last?.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input
            ChatInputView(
                text: $groupChatVM.inputText,
                isGenerating: groupChatVM.isGenerating,
                sendOnEnter: appState.settings.sendOnEnter,
                onSend: { groupChatVM.sendMessage() },
                onStop: { groupChatVM.stopGenerating() }
            )
        }
    }

    private var groupHeader: some View {
        HStack {
            Image(systemName: "person.3.fill")
                .foregroundColor(.accentColor)

            if let group = appState.selectedGroup {
                Text(group.name)
                    .font(.headline)

                Text("(\(group.members.count) members)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                groupChatVM.deleteGroup()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func groupMessageBubble(index: Int, message: ChatMessage) -> some View {
        let avatarData = groupChatVM.memberCharacters
            .first { $0.card.data.name == message.name }?.avatarData
        MessageBubbleView(
            message: message,
            avatarData: avatarData,
            index: index,
            isEditing: false,
            editText: .constant(""),
            onCopy: { groupChatVM.copyMessage(at: index) },
            onEdit: {},
            onSaveEdit: {},
            onCancelEdit: {},
            onDelete: {},
            onRegenerate: nil,
            onDeleteAndAfter: nil
        )
    }
}
