import SwiftUI

/// Chat message input with send button and configurable enter behavior
struct ChatInputView: View {
    @Binding var text: String
    let initialHeight: CGFloat
    let isGenerating: Bool
    let sendOnEnter: Bool
    var activeModel: String?
    var characterName: String?
    var tokenCount: Int = 0
    var fontSize: CGFloat = 13
    var imageGenEnabled: Bool = false
    var isGeneratingImage: Bool = false
    var onHeightChanged: ((CGFloat) -> Void)?
    let onSend: () -> Void
    let onStop: () -> Void
    var onGenerateImage: (() -> Void)?

    @FocusState private var isInputFocused: Bool
    /// The current height of the input field, managed entirely locally to avoid
    /// propagating every frame change through @Observable bindings (which causes stutter).
    @State private var localHeight: CGFloat = 0
    @State private var dragStartHeight: CGFloat = 0
    @State private var isDragging = false

    private let minInputHeight: CGFloat = 32
    private let maxInputHeight: CGFloat = 200

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
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartHeight = localHeight
                        }
                        localHeight = min(max(dragStartHeight - value.translation.height, minInputHeight), maxInputHeight)
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragStartHeight = 0
                        onHeightChanged?(localHeight)
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
                    .frame(height: localHeight)
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
            localHeight = initialHeight
        }
        .onChange(of: initialHeight) { _, newValue in
            // Sync from parent when changed externally (e.g. conversation switch),
            // but not while the user is actively dragging
            if !isDragging {
                localHeight = newValue
            }
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
