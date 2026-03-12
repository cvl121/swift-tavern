import SwiftUI

/// Defines styling rules for chat message text.
/// Colors are assigned per formatting marker — users choose what each marker "means" via color choice.
struct ChatStyle: Codable, Equatable {
    /// Color for text enclosed in "double quotes"
    var quotedTextColor: CodableColor
    /// Color for text enclosed in *asterisks* (rendered italic)
    var italicActionColor: CodableColor
    /// Color for regular unformatted text
    var narrativeColor: CodableColor
    /// Color for text enclosed in (parentheses)
    var thinkingColor: CodableColor
    /// Font size for message text
    var fontSize: Double

    static let `default` = ChatStyle(
        quotedTextColor: CodableColor(r: 0.9, g: 0.85, b: 0.55),     // warm gold — speech
        italicActionColor: CodableColor(r: 0.65, g: 0.75, b: 0.9),   // soft blue — thinking
        narrativeColor: CodableColor(r: 0.9, g: 0.9, b: 0.9),        // near-white — narration & actions
        thinkingColor: CodableColor(r: 0.7, g: 0.7, b: 0.7),         // muted gray — OOC/parentheses
        fontSize: 13
    )

    /// Light-mode-safe defaults with darker colors for readability
    static let lightDefault = ChatStyle(
        quotedTextColor: CodableColor(r: 0.6, g: 0.5, b: 0.0),
        italicActionColor: CodableColor(r: 0.2, g: 0.35, b: 0.6),
        narrativeColor: CodableColor(r: 0.1, g: 0.1, b: 0.1),
        thinkingColor: CodableColor(r: 0.45, g: 0.45, b: 0.45),
        fontSize: 13
    )

    enum CodingKeys: String, CodingKey {
        case quotedTextColor = "quoted_text_color"
        case italicActionColor = "italic_action_color"
        case narrativeColor = "narrative_color"
        case thinkingColor = "thinking_color"
        case fontSize = "font_size"
    }

    init(
        quotedTextColor: CodableColor,
        italicActionColor: CodableColor,
        narrativeColor: CodableColor,
        thinkingColor: CodableColor = CodableColor(r: 0.7, g: 0.7, b: 0.7),
        fontSize: Double
    ) {
        self.quotedTextColor = quotedTextColor
        self.italicActionColor = italicActionColor
        self.narrativeColor = narrativeColor
        self.thinkingColor = thinkingColor
        self.fontSize = fontSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        quotedTextColor = try container.decode(CodableColor.self, forKey: .quotedTextColor)
        italicActionColor = try container.decode(CodableColor.self, forKey: .italicActionColor)
        narrativeColor = try container.decode(CodableColor.self, forKey: .narrativeColor)
        thinkingColor = try container.decodeIfPresent(CodableColor.self, forKey: .thinkingColor)
            ?? CodableColor(r: 0.7, g: 0.7, b: 0.7)
        fontSize = try container.decode(Double.self, forKey: .fontSize)
    }

    /// Returns theme-appropriate colors based on the current appearance
    func effectiveColor(for codableColor: CodableColor) -> Color {
        codableColor.color
    }

    /// Returns a style adapted for the current system appearance
    static func adaptedForAppearance(_ style: ChatStyle, isDark: Bool) -> ChatStyle {
        if isDark {
            return style
        }
        let narrativeBrightness = (style.narrativeColor.r + style.narrativeColor.g + style.narrativeColor.b) / 3.0
        if narrativeBrightness > 0.7 {
            var light = ChatStyle.lightDefault
            light.fontSize = style.fontSize
            return light
        }
        return style
    }
}

/// A codable color representation
struct CodableColor: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    var color: Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }

    var nsColor: NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }

    init(from nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.r = Double(c.redComponent)
        self.g = Double(c.greenComponent)
        self.b = Double(c.blueComponent)
        self.a = Double(c.alphaComponent)
    }
}
