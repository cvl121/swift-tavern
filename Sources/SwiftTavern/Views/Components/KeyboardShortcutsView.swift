import SwiftUI

/// Displays a summary of all keyboard shortcuts in the app
struct KeyboardShortcutsView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    shortcutSection("Chat", shortcuts: [
                        ("Cmd + N", "New chat"),
                        ("Cmd + F", "Search in conversation"),
                        ("Cmd + Shift + F", "Global search"),
                        ("Cmd + R", "Regenerate last response"),
                        ("Cmd + Z", "Undo last action"),
                        ("Cmd + Shift + H", "Chat history"),
                        ("Enter", "Send message (if Send on Enter enabled)"),
                        ("Cmd + Return", "Send message (if Send on Enter disabled)"),
                        ("Shift + Enter", "New line in message"),
                    ])

                    shortcutSection("Navigation", shortcuts: [
                        ("Cmd + ,", "Settings"),
                        ("Cmd + Shift + N", "New character"),
                        ("Cmd + /", "This shortcuts panel"),
                        ("Up / Down Arrow", "Navigate messages (when enabled in Settings)"),
                        ("Escape", "Close search / cancel editing"),
                    ])

                    shortcutSection("Messages", shortcuts: [
                        ("Left / Right Arrow", "Swipe through alternative responses"),
                        ("Click character name", "View character details"),
                        ("Hover message", "Show action buttons (copy, edit, delete, etc.)"),
                    ])
                }
                .padding()
            }
        }
        .frame(width: 480, height: 500)
    }

    private func shortcutSection(_ title: String, shortcuts: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentColor)

            ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, shortcut in
                HStack {
                    Text(shortcut.0)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 180, alignment: .trailing)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
                    Text(shortcut.1)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
}
