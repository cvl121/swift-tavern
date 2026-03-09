import SwiftUI
import AppKit

/// Displays a character or user avatar with caching and fallback
struct AvatarImageView: View {
    let imageData: Data?
    let name: String
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            if let data = imageData,
               let nsImage = ImageCache.shared.loadImage(data: data, key: "\(name)-\(data.count)") {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Default head outline silhouette
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
}
