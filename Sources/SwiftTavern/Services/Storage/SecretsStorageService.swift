import Foundation

/// Service for managing API keys securely via the macOS Keychain.
/// Loads all keys once on init to avoid repeated keychain prompts.
final class SecretsStorageService {
    /// In-memory cache of API keys, loaded once from keychain
    private var keyCache: [String: String]

    init() {
        // Single keychain query loads all keys at once
        self.keyCache = KeychainHelper.loadAll()
    }

    /// Save an API key for a specific API type
    func saveAPIKey(_ key: String, for apiType: APIType) throws {
        try KeychainHelper.save(key: apiType.keychainKey, value: key)
        keyCache[apiType.keychainKey] = key
    }

    /// Retrieve an API key for a specific API type (from cache)
    func getAPIKey(for apiType: APIType) -> String? {
        keyCache[apiType.keychainKey]
    }

    /// Delete an API key for a specific API type
    func deleteAPIKey(for apiType: APIType) {
        KeychainHelper.delete(key: apiType.keychainKey)
        keyCache.removeValue(forKey: apiType.keychainKey)
    }

    /// Check if an API key is stored for a specific API type
    func hasAPIKey(for apiType: APIType) -> Bool {
        getAPIKey(for: apiType) != nil
    }
}
