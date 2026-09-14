import Foundation
import Security

struct KeychainStore {
    let service: String
    private let refreshTokenAccount = "refresh-token"
    private let legacyAccessTokenAccount = "access-token"

    func saveRefreshToken(_ token: String) throws {
        let query = baseQuery(account: refreshTokenAccount)
        let attributes: [String: Any] = [
            kSecValueData as String: Data(token.utf8),
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(updateStatus)
        }

        var item = query
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unhandledStatus(addStatus)
        }
    }

    func readRefreshToken() -> String? {
        var query = baseQuery(account: refreshTokenAccount)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func deleteSessionTokens() {
        delete(account: refreshTokenAccount)
        delete(account: legacyAccessTokenAccount)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func delete(account: String) {
        let query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
    }
}

private enum KeychainError: LocalizedError {
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        "无法安全保存登录状态，请重试"
    }
}
