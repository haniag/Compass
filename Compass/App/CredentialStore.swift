//
//  CredentialStore.swift
//  Compass
//
//  Saves the EN region + token as one Keychain item. The token is never
//  written anywhere else (no UserDefaults, no logs).
//

import Foundation
import Security

enum CredentialStore {
    private static let service = "com.fursa.Compass"
    private static let account = "en-credentials"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func load() -> ENCredentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return try? JSONDecoder().decode(ENCredentials.self, from: data)
    }

    /// Returns false if the Keychain refused the write.
    @discardableResult
    static func save(_ credentials: ENCredentials) -> Bool {
        guard let data = try? JSONEncoder().encode(credentials) else { return false }
        SecItemDelete(baseQuery as CFDictionary)

        var item = baseQuery
        item[kSecValueData as String] = data
        // Readable after the first unlock (needed for background refresh later);
        // "ThisDeviceOnly" keeps it out of backups and other devices.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
