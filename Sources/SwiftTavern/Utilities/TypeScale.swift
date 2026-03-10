import SwiftUI

/// Consistent typography scale for the app
enum TypeScale {
    static let caption: Font = .system(size: 10)
    static let footnote: Font = .system(size: 11)
    static let body: Font = .system(size: 12)
    static let bodyMedium: Font = .system(size: 12, weight: .medium)
    static let subheadline: Font = .system(size: 13)
    static let subheadlineMedium: Font = .system(size: 13, weight: .medium)
}
