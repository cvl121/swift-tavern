import SwiftUI
import AppKit

/// Chat message input with send button and configurable enter behavior.
/// Uses a native NSTextView to avoid SwiftUI re-render stutter during resize.
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

    /// The current height of the input field, managed entirely locally.
    /// Changes only affect the container frame, not the NSTextView content.
    @State private var localHeight: CGFloat = 0
    @State private var dragStartHeight: CGFloat = 0
    @State private var isDragging = false

    private let minInputHeight: CGFloat = 32
    private let maxInputHeight: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle for resizing
            dragHandle

            // Context info bar
            if activeModel != nil || characterName != nil {
                contextBar
            }

            // Input + buttons
            HStack(alignment: .bottom, spacing: 8) {
                // Native text input — survives container resize without recreation
                NativeTextInput(
                    text: $text,
                    font: .systemFont(ofSize: fontSize),
                    onSubmit: onSend,
                    sendOnEnter: sendOnEnter,
                    isGenerating: isGenerating,
                    onStop: onStop
                )
                .frame(height: localHeight)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .accessibilityLabel("Message input")

                actionButtons
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 4)
        }
        .onAppear {
            localHeight = initialHeight
        }
        .onChange(of: initialHeight) { _, newValue in
            if !isDragging {
                localHeight = newValue
            }
        }
    }

    // MARK: - Subviews

    private var dragHandle: some View {
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
    }

    private var contextBar: some View {
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

    private var actionButtons: some View {
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
