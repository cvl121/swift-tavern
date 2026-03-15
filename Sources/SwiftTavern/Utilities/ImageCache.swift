import AppKit
import Foundation
import ImageIO

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

    /// Load a thumbnail-sized image from data, using cache.
    /// Uses CGImage downsampling to avoid decoding the full image into memory.
    func loadThumbnail(data: Data, key: String, maxSize: CGFloat = 64) -> NSImage? {
        let thumbKey = "\(key)-thumb-\(Int(maxSize))"
        if let cached = image(for: thumbKey) {
            return cached
        }

        // Use ImageIO for efficient downsampled decoding — avoids loading full resolution into memory
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
            // Fall back to NSImage if CGImageSource fails
            guard let nsImage = NSImage(data: data) else { return nil }
            setImage(nsImage, for: thumbKey)
            return nsImage
        }

        let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        setImage(thumbnail, for: thumbKey)
        return thumbnail
    }
}
