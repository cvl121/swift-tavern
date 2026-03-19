import SwiftUI
import AppKit

/// A native NSTextView wrapper that auto-reports its content height.
struct NativeTextInput: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 13)
    var onSubmit: (() -> Void)?
    var sendOnEnter: Bool = true
    var isGenerating: Bool = false
    var onStop: (() -> Void)?
    /// Called whenever the text content height changes (for auto-sizing the container)
    var onContentHeightChanged: ((CGFloat) -> Void)?

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

        textView.onSubmit = onSubmit
        textView.sendOnEnter = sendOnEnter
        textView.isGenerating = isGenerating
        textView.onStop = onStop

        scrollView.documentView = textView
        context.coordinator.textView = textView

        // Report initial height
        DispatchQueue.main.async {
            context.coordinator.reportContentHeight()
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            // Text changed externally (e.g. cleared after send) — report new height
            DispatchQueue.main.async {
                context.coordinator.reportContentHeight()
            }
        }
        textView.font = font
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
            reportContentHeight()
        }

        func reportContentHeight() {
            guard let textView = textView else { return }
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            // Force layout to get accurate height
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let insets = textView.textContainerInset
            let contentHeight = usedRect.height + insets.height * 2
            parent.onContentHeightChanged?(contentHeight)
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
        let isReturn = event.keyCode == 36
        guard isReturn else {
            super.keyDown(with: event)
            return
        }

        let hasShift = event.modifierFlags.contains(.shift)
        let hasCommand = event.modifierFlags.contains(.command)

        if isGenerating {
            onStop?()
            return
        }

        if sendOnEnter {
            if hasShift {
                super.keyDown(with: event)
            } else {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onSubmit?()
                }
            }
        } else {
            if hasCommand {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onSubmit?()
                }
            } else {
                super.keyDown(with: event)
            }
        }
    }
}
