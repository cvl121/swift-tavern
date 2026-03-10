import SwiftUI
import AppKit

/// Displays a character or user avatar with caching and fallback
struct AvatarImageView: View {
    static let sizeSmall: CGFloat = 28
    static let sizeMedium: CGFloat = 36
    static let sizeLarge: CGFloat = 48
    static let sizeXLarge: CGFloat = 80

    let imageData: Data?
    let name: String
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            if let data = imageData,
               let nsImage = loadCachedImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Circle()
                    .fill(Color(.separatorColor).opacity(0.3))
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(Color(.separatorColor))
                    .padding(size * 0.05)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func loadCachedImage(data: Data) -> NSImage? {
        let key = "\(name)-\(data.count)"
        if size <= AvatarImageView.sizeMedium {
            return ImageCache.shared.loadThumbnail(data: data, key: key, maxSize: size * 2)
        }
        return ImageCache.shared.loadImage(data: data, key: key)
    }
}
