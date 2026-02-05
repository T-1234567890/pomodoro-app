import Foundation
import Security

/// Stores JWTs in the Keychain so bearer tokens are not left in plaintext preferences.
/// Tokens grant user access; keeping them in the Keychain reduces risk from disk inspection or backups.
final class TokenStorage {
    static let shared = TokenStorage()

    private let service = "com.pomodoroapp.auth"
    private let account = "user-jwt"
    private let defaultsKey = "auth.jwt.fallback"

    private init() {}

    func saveToken(jwt: String) {
        let data = Data(jwt.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        // Remove any existing entry before adding.
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)

        // If Keychain fails (e.g., in simulator), fall back to UserDefaults so login still works.
        if status != errSecSuccess {
            UserDefaults.standard.set(jwt, forKey: defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data, let jwt = String(data: data, encoding: .utf8) {
            return jwt
        }

        // Fallback for environments where Keychain is unavailable.
        return UserDefaults.standard.string(forKey: defaultsKey)
    }

    func removeToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
