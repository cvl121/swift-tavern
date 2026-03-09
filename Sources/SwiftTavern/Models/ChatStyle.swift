import SwiftUI

/// Defines styling rules for chat message text
struct ChatStyle: Codable, Equatable {
    /// Color for text enclosed in "double quotes" (dialogue)
    var quotedTextColor: CodableColor
    /// Color for text enclosed in *asterisks* (actions/emotes)
    var italicActionColor: CodableColor
    /// Color for regular narrative text
    var narrativeColor: CodableColor
    /// Font size for message text
    var fontSize: Double

    static let `default` = ChatStyle(
        quotedTextColor: CodableColor(r: 0.9, g: 0.85, b: 0.55),
        italicActionColor: CodableColor(r: 0.7, g: 0.8, b: 0.7),
        narrativeColor: CodableColor(r: 0.9, g: 0.9, b: 0.9),
        fontSize: 13
    )

    enum CodingKeys: String, CodingKey {
        case quotedTextColor = "quoted_text_color"
        case italicActionColor = "italic_action_color"
        case narrativeColor = "narrative_color"
        case fontSize = "font_size"
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
