import AppKit
import Foundation

/// Thread-safe in-memory image cache for avatar images
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.swifttavern.imagecache", attributes: .concurrent)

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }

    func image(for key: String) -> NSImage? {
        queue.sync {
            cache.object(forKey: key as NSString)
        }
    }

    func setImage(_ image: NSImage, for key: String) {
        queue.async(flags: .barrier) {
            self.cache.setObject(image, forKey: key as NSString)
        }
    }

    func removeImage(for key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeObject(forKey: key as NSString)
        }
    }

    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
        }
    }

    /// Load an image from data, using cache
    func loadImage(data: Data, key: String) -> NSImage? {
        if let cached = image(for: key) {
            return cached
        }
        guard let nsImage = NSImage(data: data) else { return nil }
        setImage(nsImage, for: key)
        return nsImage
    }
}
