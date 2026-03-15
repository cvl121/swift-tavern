import SwiftUI

/// Renders chat message text with full markdown support and optional SillyTavern-style coloring.
/// Handles block elements (headers, HRs, blockquotes, lists) and inline elements (bold, italic, code).
struct MarkdownTextView: View {
    let text: String
    var chatStyle: ChatStyle?
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - AttributedString Cache

    /// Cache for parsed and styled AttributedString results to avoid re-parsing on every render.
    /// Keyed by a hash of (text + style properties + colorScheme).
    private static var attributedStringCache = NSCache<NSString, CachedAttributedString>()
    private static let cacheSetupOnce: Void = {
        attributedStringCache.countLimit = 500
    }()

    /// Wrapper to store AttributedString in NSCache (which requires NSObject values)
    private final class CachedAttributedString: NSObject {
        let value: AttributedString
        init(_ value: AttributedString) { self.value = value }
    }

    /// Cache for parsed block arrays to avoid re-parsing on every render
    private static var blockCache = NSCache<NSString, CachedBlocks>()
    private final class CachedBlocks: NSObject {
        let value: [Block]
        init(_ value: [Block]) { self.value = value }
    }

    private static func cacheKey(text: String, style: ChatStyle?, isDark: Bool, fontSizeOverride: CGFloat?, bold: Bool) -> String {
        var hasher = Hasher()
        hasher.combine(text)
        hasher.combine(isDark)
        hasher.combine(fontSizeOverride)
        hasher.combine(bold)
        if let s = style {
            hasher.combine(s.fontSize)
            hasher.combine(s.quotedTextColor.r)
            hasher.combine(s.quotedTextColor.g)
            hasher.combine(s.quotedTextColor.b)
            hasher.combine(s.italicActionColor.r)
            hasher.combine(s.italicActionColor.g)
            hasher.combine(s.italicActionColor.b)
            hasher.combine(s.narrativeColor.r)
            hasher.combine(s.narrativeColor.g)
            hasher.combine(s.narrativeColor.b)
            hasher.combine(s.thinkingColor.r)
            hasher.combine(s.thinkingColor.g)
            hasher.combine(s.thinkingColor.b)
        }
        return "\(hasher.finalize())"
    }

    var body: some View {
        let _ = Self.cacheSetupOnce
        let style = chatStyle.map { ChatStyle.adaptedForAppearance($0, isDark: colorScheme == .dark) }
        let blocks = cachedParseBlocks(text)

        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block, style: style)
            }
        }
    }

    /// Cached version of parseBlocks to avoid re-parsing on every render
    private func cachedParseBlocks(_ text: String) -> [Block] {
        let key = "\(text.hashValue)" as NSString
        if let cached = Self.blockCache.object(forKey: key) {
            return cached.value
        }
        let blocks = parseBlocks(text)
        Self.blockCache.setObject(CachedBlocks(blocks), forKey: key)
        return blocks
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
        let base = chatStyle?.fontSize ?? ChatStyle.systemDefaultFontSize
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
            Text(cachedStyledInline(text, style: style, fontSizeOverride: fontSizeOverride, bold: bold))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(cachedParseInlineMarkdown(text, fontSizeOverride: fontSizeOverride, bold: bold))
                .font(.system(size: fontSizeOverride ?? ChatStyle.systemDefaultFontSize, weight: bold ? .bold : .regular))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Cached version of parseInlineMarkdown
    private func cachedParseInlineMarkdown(_ text: String, fontSizeOverride: CGFloat? = nil, bold: Bool = false) -> AttributedString {
        let key = Self.cacheKey(text: text, style: nil, isDark: colorScheme == .dark, fontSizeOverride: fontSizeOverride, bold: bold)
        if let cached = Self.attributedStringCache.object(forKey: key as NSString) {
            return cached.value
        }
        let result = parseInlineMarkdown(text)
        Self.attributedStringCache.setObject(CachedAttributedString(result), forKey: key as NSString)
        return result
    }

    /// Cached version of styledInline
    private func cachedStyledInline(_ text: String, style: ChatStyle, fontSizeOverride: CGFloat? = nil, bold: Bool = false) -> AttributedString {
        let key = Self.cacheKey(text: text, style: style, isDark: colorScheme == .dark, fontSizeOverride: fontSizeOverride, bold: bold)
        if let cached = Self.attributedStringCache.object(forKey: key as NSString) {
            return cached.value
        }
        let result = styledInline(text, style: style, fontSizeOverride: fontSizeOverride, bold: bold)
        Self.attributedStringCache.setObject(CachedAttributedString(result), forKey: key as NSString)
        return result
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

    // MARK: - SillyTavern-Style Text Parsing

    /// Text category for coloring purposes
    private enum TextCategory {
        case dialogue   // "double quotes"
        case thinking   // (parentheses)
        case action     // *asterisks*
        case narrative  // everything else
    }

    /// A segment of visible text with its formatting and color category
    private struct TextSegment {
        let text: String
        let category: TextCategory
        let isItalic: Bool
        let isBold: Bool
        let isCode: Bool
    }

    /// Parse raw text into styled segments by scanning markers directly.
    ///
    /// This matches SillyTavern behavior:
    /// - `*...*` → italic + action color (asterisks hidden)
    /// - `**...**` → bold (asterisks hidden), keeps contextual color
    /// - `***...***` → bold + italic + action color (asterisks hidden)
    /// - `"..."` → dialogue color (quotes visible)
    /// - `(...)` → thinking/OOC color (parens visible)
    /// - `` `...` `` → monospace code (backticks hidden)
    /// - Unclosed `*` → rest of text is action (SillyTavern greedy match)
    /// - Color priority: dialogue > thinking > action > narrative
    private func parseSegments(_ rawText: String) -> [TextSegment] {
        let chars = Array(rawText)
        let n = chars.count
        guard n > 0 else { return [] }

        // Per-character state
        var isHidden = [Bool](repeating: false, count: n)
        var isItalic = [Bool](repeating: false, count: n)
        var isBold = [Bool](repeating: false, count: n)
        var isCode = [Bool](repeating: false, count: n)
        var category = [TextCategory](repeating: .narrative, count: n)

        // Pass 0: Find inline code spans (backticks) — these override all other formatting
        var i = 0
        while i < n {
            if chars[i] == "`" {
                let start = i
                i += 1
                while i < n && chars[i] != "`" { i += 1 }
                if i < n {
                    isHidden[start] = true   // opening backtick
                    isHidden[i] = true        // closing backtick
                    for j in (start + 1)..<i {
                        isCode[j] = true
                    }
                    i += 1
                }
                continue
            }
            i += 1
        }

        // Pass 1: Parse asterisk formatting (skip code spans)
        i = 0
        var italicOpen = false
        var boldOpen = false
        while i < n {
            if isCode[i] || isHidden[i] { i += 1; continue }

            if chars[i] == "*" {
                // Count consecutive asterisks
                var count = 0
                let start = i
                while i < n && chars[i] == "*" && !isCode[i] {
                    count += 1
                    i += 1
                }

                // Mark asterisks as hidden
                for j in start..<(start + count) {
                    isHidden[j] = true
                }

                if count >= 3 {
                    boldOpen.toggle()
                    italicOpen.toggle()
                } else if count == 2 {
                    boldOpen.toggle()
                } else {
                    italicOpen.toggle()
                }
                continue
            }

            isItalic[i] = italicOpen
            isBold[i] = boldOpen
            if italicOpen {
                category[i] = .action
            }
            i += 1
        }

        // Pass 2: Quote and paren regions override color category
        // Priority: dialogue > thinking > action > narrative
        i = 0
        while i < n {
            if isHidden[i] || isCode[i] { i += 1; continue }

            // Detect "double-quoted dialogue"
            if chars[i] == "\"" {
                let start = i
                i += 1
                while i < n {
                    if chars[i] == "\"" && !isHidden[i] && !isCode[i] { break }
                    i += 1
                }
                if i < n {
                    // Mark entire quoted region including quotes as dialogue
                    for j in start...i {
                        if !isHidden[j] && !isCode[j] {
                            category[j] = .dialogue
                        }
                    }
                    i += 1
                }
                continue
            }

            // Detect (parenthesized thinking/OOC)
            if chars[i] == "(" {
                let start = i
                var depth = 1
                i += 1
                while i < n && depth > 0 {
                    if !isHidden[i] && !isCode[i] {
                        if chars[i] == "(" { depth += 1 }
                        else if chars[i] == ")" { depth -= 1 }
                    }
                    i += 1
                }
                if depth == 0 {
                    for j in start..<i {
                        if !isHidden[j] && !isCode[j] && category[j] != .dialogue {
                            category[j] = .thinking
                        }
                    }
                }
                continue
            }

            i += 1
        }

        // Build segments by grouping consecutive visible characters with same properties
        var segments: [TextSegment] = []
        var currentText = ""
        var currentCategory: TextCategory = .narrative
        var currentItalic = false
        var currentBold = false
        var currentCode = false

        for j in 0..<n {
            if isHidden[j] { continue }

            let cat = isCode[j] ? .narrative : category[j]
            let ital = isCode[j] ? false : isItalic[j]
            let bld = isCode[j] ? false : isBold[j]
            let code = isCode[j]

            if !currentText.isEmpty && (cat != currentCategory || ital != currentItalic || bld != currentBold || code != currentCode) {
                segments.append(TextSegment(text: currentText, category: currentCategory, isItalic: currentItalic, isBold: currentBold, isCode: currentCode))
                currentText = ""
            }

            currentText.append(chars[j])
            currentCategory = cat
            currentItalic = ital
            currentBold = bld
            currentCode = code
        }

        if !currentText.isEmpty {
            segments.append(TextSegment(text: currentText, category: currentCategory, isItalic: currentItalic, isBold: currentBold, isCode: currentCode))
        }

        return segments
    }

    /// Build a styled AttributedString from raw text by parsing markers directly.
    /// This processes the raw text first (like SillyTavern) instead of relying on
    /// markdown parsing, ensuring consistent color application.
    private func styledInline(_ text: String, style: ChatStyle, fontSizeOverride: CGFloat? = nil, bold: Bool = false) -> AttributedString {
        let segments = parseSegments(text)
        var result = AttributedString()
        let baseSize = fontSizeOverride ?? CGFloat(style.fontSize)

        for segment in segments {
            var attr = AttributedString(segment.text)

            // Apply color based on category
            if segment.isCode {
                attr.foregroundColor = style.narrativeColor.color
            } else {
                switch segment.category {
                case .dialogue:
                    attr.foregroundColor = style.quotedTextColor.color
                case .thinking:
                    attr.foregroundColor = style.thinkingColor.color
                case .action:
                    attr.foregroundColor = style.italicActionColor.color
                case .narrative:
                    attr.foregroundColor = style.narrativeColor.color
                }
            }

            // Apply font with proper italic/bold
            let weight: Font.Weight = (segment.isBold || bold) ? .bold : .regular
            if segment.isCode {
                attr.font = .system(size: max(baseSize - 1, 10), weight: weight, design: .monospaced)
            } else if segment.isItalic {
                attr.font = .system(size: baseSize, weight: weight).italic()
            } else {
                attr.font = .system(size: baseSize, weight: weight)
            }

            result += attr
        }

        return result
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            MarkdownTextView(text: "**Bold** and *italic* and `code`\n\nA paragraph")
            Divider()
            MarkdownTextView(
                text: "She walks over slowly. \"Hello there!\" *I hope she doesn't notice me staring.*",
                chatStyle: .default
            )
            Divider()
            MarkdownTextView(
                text: "*\"Hello there!\"* she said, leaning against the wall.",
                chatStyle: .default
            )
            Divider()
            MarkdownTextView(
                text: "*I wonder what she wants...* \"Oh, hey!\" He waves awkwardly. (OOC: great scene!)",
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
