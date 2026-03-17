import SwiftUI

/// Chat message input with send button and configurable enter behavior
struct ChatInputView: View {
    @Binding var text: String
    @Binding var inputHeight: CGFloat
    let isGenerating: Bool
    let sendOnEnter: Bool
    var activeModel: String?
    var characterName: String?
    var tokenCount: Int = 0
    var fontSize: CGFloat = 13
    var imageGenEnabled: Bool = false
    var isGeneratingImage: Bool = false
    var onHeightChanged: (() -> Void)?
    let onSend: () -> Void
    let onStop: () -> Void
    var onGenerateImage: (() -> Void)?

    @FocusState private var isInputFocused: Bool
    /// Committed height that drives the TextEditor frame (only updates on drag end)
    @State private var committedHeight: CGFloat = 0
    /// Transient height while dragging (drives the frame during gesture)
    @GestureState private var dragOffset: CGFloat = 0

    private let minInputHeight: CGFloat = 32
    private let maxInputHeight: CGFloat = 200

    /// The effective height: committed + drag offset, clamped
    private var effectiveHeight: CGFloat {
        min(max(committedHeight - dragOffset, minInputHeight), maxInputHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle for resizing
            ZStack {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 12)

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .frame(width: 5, height: 5)
                    }
                }
                .foregroundColor(.secondary.opacity(0.5))
            }
            .contentShape(Rectangle())
            .cursor(.resizeUpDown)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        let newHeight = min(max(committedHeight - value.translation.height, minInputHeight), maxInputHeight)
                        committedHeight = newHeight
                        inputHeight = newHeight
                        onHeightChanged?()
                    }
            )

            // Context info bar
            if activeModel != nil || characterName != nil {
                HStack(spacing: 6) {
                    if let name = characterName {
                        Text("Chatting with \(name)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    if tokenCount > 0 {
                        Text("~\(tokenCount) tokens")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if let model = activeModel {
                        Spacer()
                        Text(model)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 2)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $text)
                    .font(.system(size: fontSize))
                    .frame(height: effectiveHeight)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(isInputFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5))
                    .focused($isInputFocused)
                    .accessibilityLabel("Message input")

                VStack(spacing: 6) {
                    if imageGenEnabled {
                        Button(action: { onGenerateImage?() }) {
                            Image(systemName: isGeneratingImage ? "hourglass" : "photo")
                                .font(.system(size: 16))
                                .foregroundColor(isGeneratingImage ? .secondary : .accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(isGeneratingImage || isGenerating)
                        .help("Generate an image of the current scene")
                    }

                    Button(action: {
                        if isGenerating {
                            onStop()
                        } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend()
                        }
                    }) {
                        Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isGenerating ? .red : .accentColor)
                    }
                    .buttonStyle(.plain)
                    .help(isGenerating ? "Stop generating" : (sendOnEnter ? "Send message (Enter)" : "Send message (Cmd+Return)"))
                    .animation(.easeInOut(duration: 0.15), value: isGenerating)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 4)
        }
        .onAppear {
            committedHeight = inputHeight
        }
        .onChange(of: inputHeight) { _, newValue in
            // Sync from binding when changed externally (e.g. conversation switch)
            committedHeight = newValue
        }
        .onKeyPress(.return, phases: .down) { keyPress in
            if isGenerating {
                onStop()
                return .handled
            }
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
