import Foundation
#if canImport(Security)
import Security
#endif

#if !canImport(Security)
// OSStatus is a Darwin typealias for Int32; define it here for Linux compatibility.
public typealias OSStatus = Int32
#endif

/// Thin wrapper around Security.framework Keychain APIs.
/// Falls back to a thread-safe in-memory store on Linux (for unit testing).
public final class KeychainManager: Sendable {
    public static let shared = KeychainManager()
    private init() {}

    // MARK: - String API (passwords)

#if canImport(Security)
    /// Saves a password string to the Keychain under `tag`, overwriting any prior entry.
    public func save(password: String, for tag: String) throws {
        try saveData(Data(password.utf8), for: tag)
    }

    /// Retrieves a password string stored under `tag`.
    public func retrieve(for tag: String) throws -> String {
        let data = try retrieveData(for: tag)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound(tag)
        }
        return string
    }

    // MARK: - Data API (SSH private keys)

    /// Saves arbitrary `data` (e.g. a PEM-encoded private key) under `tag`.
    public func saveData(_ data: Data, for tag: String) throws {
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    "ShellLite",
            kSecAttrAccount:    tag,
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)    // remove stale entry first
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    /// Retrieves raw `Data` stored under `tag`.
    public func retrieveData(for tag: String) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  "ShellLite",
            kSecAttrAccount:  tag,
            kSecReturnData:   true,
            kSecMatchLimit:   kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.notFound(tag)
        }
        return data
    }

    /// Deletes the Keychain entry for `tag`. Idempotent — no error if absent.
    public func delete(tag: String) {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  "ShellLite",
            kSecAttrAccount:  tag,
        ]
        SecItemDelete(query as CFDictionary)
    }

#else
    // ── Linux stub (in-memory, for unit testing without Security.framework) ──
    private let lock = NSLock()
    nonisolated(unsafe) private var store: [String: Data] = [:]

    public func save(password: String, for tag: String) throws {
        try saveData(Data(password.utf8), for: tag)
    }

    public func retrieve(for tag: String) throws -> String {
        let data = try retrieveData(for: tag)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound(tag)
        }
        return string
    }

    public func saveData(_ data: Data, for tag: String) throws {
        lock.withLock { store[tag] = data }
    }

    public func retrieveData(for tag: String) throws -> Data {
        guard let data = lock.withLock({ store[tag] }) else {
            throw KeychainError.notFound(tag)
        }
        return data
    }

    public func delete(tag: String) {
        lock.withLock { _ = store.removeValue(forKey: tag) }
    }
#endif
}

// MARK: - Errors

public enum KeychainError: Error, Sendable {
    case saveFailed(OSStatus)
    case notFound(String)
}
