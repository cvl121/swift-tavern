import SwiftUI

/// Chat message input with send button and configurable enter behavior
struct ChatInputView: View {
    @Binding var text: String
    let isGenerating: Bool
    let sendOnEnter: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @State private var inputHeight: CGFloat = 32

    private let minInputHeight: CGFloat = 32
    private let maxInputHeight: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle for resizing
            Rectangle()
                .fill(Color.clear)
                .frame(height: 6)
                .contentShape(Rectangle())
                .cursor(.resizeUpDown)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newHeight = inputHeight - value.translation.height
                            inputHeight = min(max(newHeight, minInputHeight), maxInputHeight)
                        }
                )

            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .frame(height: inputHeight)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)

                if isGenerating {
                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Stop generating")
                } else {
                    Button(action: {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help(sendOnEnter ? "Send message (Enter)" : "Send message (Cmd+Return)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 4)
        }
        .onKeyPress(.return, phases: .down) { keyPress in
            guard !isGenerating else { return .ignored }
            if sendOnEnter {
                if keyPress.modifiers.contains(.shift) {
                    return .ignored
                }
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onSend()
                    return .handled
                }
                return .ignored
            } else {
                if keyPress.modifiers.contains(.command) {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                        return .handled
                    }
                }
                return .ignored
            }
        }
    }
}

// MARK: - Cursor modifier

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
