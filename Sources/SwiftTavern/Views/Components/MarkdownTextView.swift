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
        case codeBlock(language: String?, code: String)
        case paragraph(String)
        case empty
    }

    private func parseBlocks(_ text: String) -> [Block] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [Block] = []
        var paragraphLines: [String] = []
        var inCodeBlock = false
        var codeBlockLanguage: String?
        var codeBlockLines: [String] = []

        func flushParagraph() {
            if !paragraphLines.isEmpty {
                blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
                paragraphLines.removeAll()
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block: ```language ... ```
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    // Close code block
                    blocks.append(.codeBlock(language: codeBlockLanguage, code: codeBlockLines.joined(separator: "\n")))
                    codeBlockLines.removeAll()
                    codeBlockLanguage = nil
                    inCodeBlock = false
                } else {
                    // Open code block
                    flushParagraph()
                    let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeBlockLanguage = lang.isEmpty ? nil : lang
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeBlockLines.append(line)
                continue
            }

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

        // Close unclosed code block
        if inCodeBlock && !codeBlockLines.isEmpty {
            blocks.append(.codeBlock(language: codeBlockLanguage, code: codeBlockLines.joined(separator: "\n")))
        }

        flushParagraph()
        return blocks
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func renderBlock(_ block: Block, style: ChatStyle?) -> some View {
        switch block {
        case .heading(let level, let text):
            renderInline(text, style: style, fontSizeOverride: headingSize(level), bold: true)
                .padding(.top, level <= 2 ? 6 : 2)

        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: 0) {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                }
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(code)
                        .font(.system(size: max((chatStyle?.fontSize ?? 13) - 1, 10), design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .padding(10)
                }
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(.textBackgroundColor).opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separatorColor), lineWidth: 0.5))
            .padding(.vertical, 4)

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
    private func renderInline(_ text: String, style: ChatStyle?, fontSizeOverride: CGFloat? = nil, bold: Bool = false) -> some View {
        if let style {
            Text(styledInline(text, style: style, fontSizeOverride: fontSizeOverride, bold: bold))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(parseInlineMarkdown(text))
                .font(.system(size: fontSizeOverride ?? 13, weight: bold ? .bold : .regular))
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

    /// Parse inline markdown then apply chat style colors per character segment.
    ///
    /// Color priority (matches SillyTavern behavior):
    /// - Quoted text `"..."` always gets dialogue color, even inside `*asterisks*`
    /// - Italic text outside quotes gets action/emote color
    /// - Bold text keeps its contextual color (dialogue if quoted, narrative otherwise)
    /// - All other text gets narrative color
    private func styledInline(_ text: String, style: ChatStyle, fontSizeOverride: CGFloat? = nil, bold: Bool = false) -> AttributedString {
        var attributed = parseInlineMarkdown(text)
        let plainText = String(attributed.characters)
        let colorMap = buildColorMap(for: plainText)

        // Collect run info first (ranges and emphasis/strong status)
        struct RunInfo {
            let range: Range<AttributedString.Index>
            let length: Int
            let hasEmphasis: Bool
            let hasStrong: Bool
        }
        var runs: [RunInfo] = []
        for run in attributed.runs {
            let len = attributed[run.range].characters.count
            let intent = run.inlinePresentationIntent
            let emphasis = intent?.contains(.emphasized) ?? false
            let strong = intent?.contains(.stronglyEmphasized) ?? false
            runs.append(RunInfo(range: run.range, length: len, hasEmphasis: emphasis, hasStrong: strong))
        }

        // Apply colors by splitting every run at quote boundaries
        var charOffset = 0
        for runInfo in runs {
            let runStart = charOffset
            let runEnd = charOffset + runInfo.length

            // Split this run into segments where quote status changes
            var segStart = runStart
            while segStart < runEnd {
                let isQuoted = segStart < colorMap.count && colorMap[segStart]
                var segEnd = segStart + 1
                while segEnd < runEnd {
                    let nextIsQuoted = segEnd < colorMap.count && colorMap[segEnd]
                    if nextIsQuoted != isQuoted { break }
                    segEnd += 1
                }

                // Convert character offsets to AttributedString indices
                let segStartIdx = attributed.characters.index(runInfo.range.lowerBound, offsetBy: segStart - charOffset)
                let segEndIdx = attributed.characters.index(runInfo.range.lowerBound, offsetBy: segEnd - charOffset)
                let segRange = segStartIdx..<segEndIdx

                // Color priority: quoted text always gets dialogue color,
                // italic non-quoted gets action color, everything else narrative
                if isQuoted {
                    attributed[segRange].foregroundColor = style.quotedTextColor.color
                } else if runInfo.hasEmphasis {
                    attributed[segRange].foregroundColor = style.italicActionColor.color
                } else {
                    attributed[segRange].foregroundColor = style.narrativeColor.color
                }

                segStart = segEnd
            }

            let size = fontSizeOverride ?? CGFloat(style.fontSize)
            let weight: Font.Weight = bold ? .bold : .regular
            if attributed[runInfo.range].font == nil {
                attributed[runInfo.range].font = .system(size: size, weight: weight)
            } else if bold || fontSizeOverride != nil {
                // Override font size/weight for headings while preserving italic intent
                attributed[runInfo.range].font = .system(size: size, weight: weight)
            }

            charOffset += runInfo.length
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
                text: "*\"Hello there!\"* she said, *leaning against the wall.*",
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
