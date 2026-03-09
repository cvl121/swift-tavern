import Foundation

extension FileManager {
    /// Application Support directory for SwiftTavern
    static var appSupportDirectory: URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to home directory if app support is somehow unavailable
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".swifttavern", isDirectory: true)
        }
        return appSupport.appendingPathComponent("SwiftTavern", isDirectory: true)
    }
}
