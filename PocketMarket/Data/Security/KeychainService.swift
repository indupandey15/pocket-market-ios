//
//  KeychainService.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  This mock API doesn't require auth, but the assignment explicitly calls
//  out "secure storage for any tokens" — this is where a real auth token
//  would live (never UserDefaults/Core Data in plaintext). Wired up now so
//  it's a one-line call away if auth is added later.
//

import Foundation
import Security

protocol KeychainServiceProtocol {
    func set(_ value: String, forKey key: String) throws
    func get(_ key: String) -> String?
    func delete(_ key: String)
}

struct KeychainService: KeychainServiceProtocol {
    enum KeychainError: Error { case unhandledStatus(OSStatus) }

    func set(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary) // replace any existing value

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandledStatus(status) }
    }

    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}


