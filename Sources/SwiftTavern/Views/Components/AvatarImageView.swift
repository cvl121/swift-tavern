import SwiftUI
import AppKit
import ImageIO

/// Displays a character or user avatar with caching and fallback.
/// Shows a styled default profile picture for characters without custom avatars.
struct AvatarImageView: View {
    static let sizeSmall: CGFloat = 28
    static let sizeMedium: CGFloat = 36
    static let sizeLarge: CGFloat = 48
    static let sizeXLarge: CGFloat = 80

    let imageData: Data?
    let name: String
    var size: CGFloat = 40

    /// Cache of data keys known to be placeholder/invalid images (1x1 px)
    private static var invalidImageKeys = Set<String>()
    /// Cache of data keys known to have valid dimensions (skip re-checking CGImageSource)
    private static var validImageKeys = Set<String>()

    var body: some View {
        ZStack {
            if let nsImage = loadValidImage() {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "person.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.accentColor.opacity(0.5))
                    .padding(size * 0.24)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("\(name) avatar")
    }

    /// Load image, rejecting minimal placeholder PNGs (1x1 pixel images created for characters without avatars)
    private func loadValidImage() -> NSImage? {
        guard let data = imageData, !data.isEmpty else { return nil }

        let key = "\(name)-\(data.count)"

        // Fast path: already known to be invalid
        if Self.invalidImageKeys.contains(key) { return nil }

        // Only run CGImageSource dimension check if we haven't validated this key before
        if !Self.validImageKeys.contains(key) {
            if let source = CGImageSourceCreateWithData(data as CFData, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
               let width = props[kCGImagePropertyPixelWidth as String] as? Int,
               let height = props[kCGImagePropertyPixelHeight as String] as? Int,
               width <= 1, height <= 1 {
                Self.invalidImageKeys.insert(key)
                return nil
            }
            Self.validImageKeys.insert(key)
        }

        if size <= AvatarImageView.sizeMedium {
            return ImageCache.shared.loadThumbnail(data: data, key: key, maxSize: size * 2)
        }
        return ImageCache.shared.loadImage(data: data, key: key)
    }
}
