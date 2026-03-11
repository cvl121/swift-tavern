import SwiftUI

/// Environment key for app-wide UI text scale factor
private struct UIScaleKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

extension EnvironmentValues {
    var uiScale: Double {
        get { self[UIScaleKey.self] }
        set { self[UIScaleKey.self] = newValue }
    }
}

extension View {
    /// Passes the UI scale factor into the environment for child views
    func uiScaled(_ scale: Double) -> some View {
        self.environment(\.uiScale, scale)
    }

    /// Applies the UI scale as a default font size (for views without explicit fonts)
    func applyUIScale(_ scale: Double) -> some View {
        let baseFontSize = 13.0 * scale
        return self
            .font(.system(size: baseFontSize))
            .environment(\.uiScale, scale)
    }
}

/// Convenience to compute a scaled font size
func scaledFontSize(_ base: Double, scale: Double) -> Double {
    base * scale
}
