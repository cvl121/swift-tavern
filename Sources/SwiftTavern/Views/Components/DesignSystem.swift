import SwiftUI

/// Centralized design tokens for consistent UI
enum DS {
    // MARK: - Spacing
    static let spacing2: CGFloat = 2
    static let spacing4: CGFloat = 4
    static let spacing6: CGFloat = 6
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24

    // MARK: - Corner Radius
    static let cornerSmall: CGFloat = 4
    static let cornerMedium: CGFloat = 8
    static let cornerLarge: CGFloat = 12

    // MARK: - Semantic Colors
    enum Colors {
        static let surface = Color(.windowBackgroundColor)
        static let surfaceSecondary = Color(.controlBackgroundColor)
        static let surfaceHover = Color.primary.opacity(0.05)
        static let surfaceSelected = Color.accentColor.opacity(0.15)
        static let border = Color(.separatorColor)
        static let borderSubtle = Color(.separatorColor).opacity(0.5)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textAccent = Color.accentColor
        static let destructive = Color.red
        static let success = Color.green
        static let warning = Color.orange
    }

    // MARK: - Font
    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: - Section Header
    static func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
}

/// Reusable detail view header bar
struct DetailHeaderView: View {
    let title: String
    var actions: (() -> AnyView)?

    init(_ title: String, @ViewBuilder actions: @escaping () -> some View) {
        self.title = title
        self.actions = { AnyView(actions()) }
    }

    init(_ title: String) {
        self.title = title
        self.actions = nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.title2.bold())
                Spacer()
                actions?()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()
        }
    }
}
