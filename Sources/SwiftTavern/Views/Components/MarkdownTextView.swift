import SwiftUI

/// Renders chat message text with full markdown support and optional SillyTavern-style coloring.
/// Handles block elements (headers, HRs, blockquotes, lists) and inline elements (bold, italic, code).
struct MarkdownTextView: View {
    let text: String
    var chatStyle: ChatStyle?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = chatStyle.map { ChatStyle.adaptedForAppearance($0, isDark: colorScheme == .dark) }
        let blocks = parseBlocks(text)

        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block, style: style)
            }
        }
    }

    // MARK: - Block Parsing

    private enum Block {
        case heading(level: Int, text: String)
        case horizontalRule
        case blockquote(String)
        case listItem(String)
        case paragraph(String)
        case empty
    }

    private func parseBlocks(_ text: String) -> [Block] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [Block] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            if !paragraphLines.isEmpty {
                blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
                paragraphLines.removeAll()
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Horizontal rule: ---, ***, ___, or -- (SillyTavern style)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" || trimmed == "--" {
                flushParagraph()
                blocks.append(.horizontalRule)
                continue
            }

            // Headers: # through ######
            if let range = trimmed.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                flushParagraph()
                let hashes = trimmed[trimmed.startIndex..<range.upperBound]
                    .filter { $0 == "#" }
                let level = hashes.count
                let headerText = String(trimmed[range.upperBound...])
                blocks.append(.heading(level: level, text: headerText))
                continue
            }

            // Blockquote: > text
            if trimmed.hasPrefix("> ") {
                flushParagraph()
                let quoteText = String(trimmed.dropFirst(2))
                blocks.append(.blockquote(quoteText))
                continue
            }

            // Unordered list: - item, * item, + item
            if trimmed.count >= 2,
               (trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ")),
               let spaceIdx = trimmed.index(trimmed.startIndex, offsetBy: 2, limitedBy: trimmed.endIndex) {
                flushParagraph()
                blocks.append(.listItem(String(trimmed[spaceIdx...])))
                continue
            }

            // Ordered list: 1. item, 2. item, etc.
            if let range = trimmed.range(of: #"^[0-9]+\.\s+"#, options: .regularExpression) {
                flushParagraph()
                let prefix = String(trimmed[trimmed.startIndex..<range.upperBound]).trimmingCharacters(in: .whitespaces)
                let content = String(trimmed[range.upperBound...])
                blocks.append(.listItem("\(prefix) \(content)"))
                continue
            }

            // Empty line
            if trimmed.isEmpty {
                flushParagraph()
                blocks.append(.empty)
                continue
            }

            // Regular text line - accumulate into paragraph
            paragraphLines.append(line)
        }

        flushParagraph()
        return blocks
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func renderBlock(_ block: Block, style: ChatStyle?) -> some View {
        switch block {
        case .heading(let level, let text):
            renderInline(text, style: style)
                .font(.system(size: headingSize(level), weight: .bold))
                .padding(.top, level <= 2 ? 6 : 2)

        case .horizontalRule:
            Divider()
                .padding(.vertical, 4)

        case .blockquote(let text):
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3)
                renderInline(text, style: style)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)

        case .listItem(let text):
            HStack(alignment: .top, spacing: 6) {
                Text("\u{2022}")
                    .foregroundColor(.secondary)
                renderInline(text, style: style)
            }

        case .paragraph(let text):
            renderInline(text, style: style)

        case .empty:
            Spacer().frame(height: 4)
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        let base = chatStyle?.fontSize ?? 13
        switch level {
        case 1: return base + 10
        case 2: return base + 6
        case 3: return base + 3
        case 4: return base + 1
        default: return base
        }
    }

    // MARK: - Inline Rendering

    @ViewBuilder
    private func renderInline(_ text: String, style: ChatStyle?) -> some View {
        if let style {
            Text(styledInline(text, style: style))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(parseInlineMarkdown(text))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }
        return AttributedString(text)
    }

    /// Parse inline markdown then apply chat style colors
    private func styledInline(_ text: String, style: ChatStyle) -> AttributedString {
        var attributed = parseInlineMarkdown(text)
        let plainText = String(attributed.characters)
        let colorMap = buildColorMap(for: plainText)

        var offset = 0
        for run in attributed.runs {
            let runLength = attributed[run.range].characters.count
            let runStart = offset
            let runEnd = offset + runLength
            let hasEmphasis = run.inlinePresentationIntent?.contains(.emphasized) ?? false

            if hasEmphasis {
                attributed[run.range].foregroundColor = style.italicActionColor.color
            } else {
                let quoteCount = (runStart..<runEnd).filter { $0 < colorMap.count && colorMap[$0] }.count
                if quoteCount > runLength / 2 && quoteCount > 0 {
                    attributed[run.range].foregroundColor = style.quotedTextColor.color
                } else {
                    attributed[run.range].foregroundColor = style.narrativeColor.color
                }
            }

            if attributed[run.range].font == nil {
                attributed[run.range].font = .system(size: style.fontSize)
            }

            offset = runEnd
        }

        return attributed
    }

    /// Build a per-character map marking which characters are inside "quotes"
    private func buildColorMap(for text: String) -> [Bool] {
        var map = [Bool](repeating: false, count: text.count)
        let chars = Array(text)
        var i = 0

        while i < chars.count {
            if chars[i] == "\"" {
                let start = i
                i += 1
                while i < chars.count && chars[i] != "\"" {
                    i += 1
                }
                if i < chars.count {
                    for j in start...i {
                        map[j] = true
                    }
                    i += 1
                }
            } else {
                i += 1
            }
        }

        return map
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            MarkdownTextView(text: "**Bold** and *italic* and `code`\n\nA paragraph")
            Divider()
            MarkdownTextView(
                text: "*She walks over slowly.* \"Hello there!\" She waves her hand.",
                chatStyle: .default
            )
            Divider()
            MarkdownTextView(
                text: "# Main Heading\n\n## Sub Heading\n\n### Small Heading\n\nRegular text with **bold** and *italic*.\n\n---\n\n> This is a blockquote\n\n- List item one\n- List item two\n- List item three\n\n--\n\n1. First\n2. Second\n3. Third",
                chatStyle: .default
            )
        }
        .padding()
    }
    .frame(width: 400, height: 600)
}
