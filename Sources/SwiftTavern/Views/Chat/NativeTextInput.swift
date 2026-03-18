import SwiftUI
import AppKit

/// A native NSTextView wrapper that can be resized without SwiftUI body re-evaluation.
/// This avoids the stutter caused by SwiftUI destroying and recreating TextEditor
/// on every @State change during drag-to-resize.
struct NativeTextInput: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 13)
    var onSubmit: (() -> Void)?
    var sendOnEnter: Bool = true
    var isGenerating: Bool = false
    var onStop: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = InputTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = font
        textView.textColor = .textColor
        textView.insertionPointColor = .textColor
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.string = text

        // Store callbacks on the textView subclass
        textView.onSubmit = onSubmit
        textView.sendOnEnter = sendOnEnter
        textView.isGenerating = isGenerating
        textView.onStop = onStop

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        // Only update text if it changed externally (not from user typing)
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
        textView.font = font
        // Update callbacks
        textView.onSubmit = onSubmit
        textView.sendOnEnter = sendOnEnter
        textView.isGenerating = isGenerating
        textView.onStop = onStop
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeTextInput
        weak var textView: InputTextView?

        init(_ parent: NativeTextInput) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// Custom NSTextView subclass that intercepts Enter key for send behavior
final class InputTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var sendOnEnter: Bool = true
    var isGenerating: Bool = false
    var onStop: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 // Return key
        guard isReturn else {
            super.keyDown(with: event)
            return
        }

        let hasShift = event.modifierFlags.contains(.shift)
        let hasCommand = event.modifierFlags.contains(.command)

        // If generating, Enter stops generation
        if isGenerating {
            onStop?()
            return
        }

        if sendOnEnter {
            if hasShift {
                // Shift+Enter = newline
                super.keyDown(with: event)
            } else {
                // Enter = send
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onSubmit?()
                }
            }
        } else {
            if hasCommand {
                // Cmd+Enter = send
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onSubmit?()
                }
            } else {
                // Enter = newline
                super.keyDown(with: event)
            }
        }
    }
}
