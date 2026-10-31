import Foundation
import Security

/// The API key is stored only in the user's login Keychain, encrypted by macOS.
enum Keychain {
    private static let service = "app.pico.mac"
    private static let account = "anthropic-api-key"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// Whether a key is stored, without reading it (reading can prompt for the keychain password).
    static func hasAPIKey() -> Bool {
        var query = query
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess
    }

    static func apiKey() -> String? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else { return nil }
        return key
    }

    static func setAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            SecItemDelete(query as CFDictionary)
            return
        }
        // Delete + add rather than update: a fresh item is owned by the current build of the app,
        // so a rebuilt (re-signed) Pico can read it without macOS asking for the keychain password.
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = Data(trimmed.utf8)
        let status = SecItemAdd(insert as CFDictionary, nil)
        if status != errSecSuccess {
            Log.app.error("Keychain save failed: OSStatus \(status)")
        }
    }
}
