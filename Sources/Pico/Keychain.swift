import Foundation
import Security

/// API keys are stored only in the user's login Keychain, encrypted by macOS, one item per provider.
enum Keychain {
    private static let service = "app.pico.mac"

    private static func query(for provider: Provider) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(provider.rawValue)-api-key",
        ]
    }

    /// Whether a key is stored, without reading it (reading can prompt for the keychain password).
    static func hasAPIKey(for provider: Provider) -> Bool {
        var query = query(for: provider)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess
    }

    static func apiKey(for provider: Provider) -> String? {
        var query = query(for: provider)
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

    static func setAPIKey(_ key: String, for provider: Provider) {
        let query = query(for: provider)
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        // Delete + add rather than update: a fresh item is owned by the current build of the app,
        // so a rebuilt (re-signed) Pico can read it without macOS asking for the keychain password.
        SecItemDelete(query as CFDictionary)
        guard !trimmed.isEmpty else { return }
        var insert = query
        insert[kSecValueData as String] = Data(trimmed.utf8)
        let status = SecItemAdd(insert as CFDictionary, nil)
        if status != errSecSuccess {
            Log.app.error("Keychain save failed for \(provider.rawValue): OSStatus \(status)")
        }
    }
}
