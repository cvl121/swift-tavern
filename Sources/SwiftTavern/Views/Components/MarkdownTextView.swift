import SwiftUI

/// Renders chat message text with optional SillyTavern-style coloring
struct MarkdownTextView: View {
    let text: String
    var chatStyle: ChatStyle?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let style = chatStyle {
            let effectiveStyle = ChatStyle.adaptedForAppearance(style, isDark: colorScheme == .dark)
            Text(styledText(style: effectiveStyle))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(renderMarkdown())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func renderMarkdown() -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }
        return AttributedString(text)
    }

    /// Build an AttributedString with custom colors for quoted text, actions, and narrative
    private func styledText(style: ChatStyle) -> AttributedString {
        var result = AttributedString()
        let lines = text.components(separatedBy: "\n")

        for (lineIndex, line) in lines.enumerated() {
            if lineIndex > 0 {
                result.append(AttributedString("\n"))
            }
            result.append(colorLine(line, style: style))
        }
        return result
    }

    /// Color a single line based on its content patterns
    private func colorLine(_ line: String, style: ChatStyle) -> AttributedString {
        var result = AttributedString()
        var remaining = line[line.startIndex...]

        while !remaining.isEmpty {
            // Check for quoted text: "..."
            if remaining.first == "\"" {
                if let closeIndex = remaining.dropFirst().firstIndex(of: "\"") {
                    let endIndex = remaining.index(after: closeIndex)
                    let quoted = String(remaining[remaining.startIndex...endIndex])
                    var attr = AttributedString(quoted)
                    attr.foregroundColor = style.quotedTextColor.color
                    result.append(attr)
                    remaining = remaining[remaining.index(after: endIndex)...]
                    continue
                }
            }

            // Check for action text: *...*
            if remaining.first == "*" && !remaining.dropFirst().isEmpty {
                // Don't match ** (bold markdown)
                let afterStar = remaining.index(after: remaining.startIndex)
                if remaining[afterStar] != "*" {
                    if let closeIndex = remaining.dropFirst().firstIndex(of: "*") {
                        let endIndex = remaining.index(after: closeIndex)
                        let action = String(remaining[remaining.startIndex...closeIndex])
                        var attr = AttributedString(action)
                        attr.foregroundColor = style.italicActionColor.color
                        attr.inlinePresentationIntent = .emphasized
                        result.append(attr)
                        remaining = remaining[endIndex...]
                        continue
                    }
                }
            }

            // Regular narrative text - consume until next special character
            var endIdx = remaining.index(after: remaining.startIndex)
            while endIdx < remaining.endIndex && remaining[endIdx] != "\"" && remaining[endIdx] != "*" {
                endIdx = remaining.index(after: endIdx)
            }
            let segment = String(remaining[remaining.startIndex..<endIdx])
            var attr = AttributedString(segment)
            attr.foregroundColor = style.narrativeColor.color
            attr.font = .system(size: style.fontSize)
            result.append(attr)
            remaining = remaining[endIdx...]
        }

        return result
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        MarkdownTextView(text: "**Bold** and *italic* and `code`\n\nA paragraph")
        MarkdownTextView(
            text: "*She walks over slowly.* \"Hello there!\" She waves her hand.",
            chatStyle: .default
        )
    }
    .padding()
}
