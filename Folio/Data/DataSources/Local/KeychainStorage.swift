import Foundation
import Security

protocol KeychainClient {
    func loadData(service: String, account: String) throws -> Data?
    func saveData(_ data: Data, service: String, account: String) throws
    func removeData(service: String, account: String) throws
}

final class KeychainStorage: LocalStorageProtocol {
    private static let legacyService = "com.nustechnology.Folio"

    private let client: KeychainClient
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let service: String

    init(
        client: KeychainClient = SystemKeychainClient(),
        service: String = Bundle.main.bundleIdentifier ?? "com.nus.folio"
    ) {
        self.client = client
        self.service = service
        migrateFromLegacyIfNeeded()
    }

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        try client.saveData(encoder.encode(value), service: service, account: key)
    }

    func load<T: Codable>(forKey key: String) throws -> T? {
        if let data = try client.loadData(service: service, account: key) {
            return try decoder.decode(T.self, from: data)
        }
        if service != Self.legacyService,
           let data = try client.loadData(service: Self.legacyService, account: key) {
            return try decoder.decode(T.self, from: data)
        }
        return nil
    }

    func remove(forKey key: String) throws {
        var firstError: Error?
        do {
            try client.removeData(service: service, account: key)
        } catch {
            firstError = error
        }
        if service != Self.legacyService {
            do {
                try client.removeData(service: Self.legacyService, account: key)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
    }

    private func migrateFromLegacyIfNeeded() {
        guard service != Self.legacyService else { return }
        let knownKeys = ["session", "user", "auth"]
        for key in knownKeys {
            guard let data = try? client.loadData(service: Self.legacyService, account: key) else { continue }
            do {
                try client.saveData(data, service: service, account: key)
                try client.removeData(service: Self.legacyService, account: key)
            } catch {
                break
            }
        }
    }

}

protocol SecItemClient {
    func copyMatching(_ query: [CFString: Any]) -> (status: OSStatus, data: Data?)
    func update(_ query: [CFString: Any], attributes: [CFString: Any]) -> OSStatus
    func add(_ attributes: [CFString: Any]) -> OSStatus
    func delete(_ query: [CFString: Any]) -> OSStatus
}

struct SystemSecItemClient: SecItemClient {
    func copyMatching(_ query: [CFString: Any]) -> (status: OSStatus, data: Data?) {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result as? Data)
    }

    func update(_ query: [CFString: Any], attributes: [CFString: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    func add(_ attributes: [CFString: Any]) -> OSStatus {
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func delete(_ query: [CFString: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }
}

final class SystemKeychainClient: KeychainClient {
    private let secItem: SecItemClient

    init(secItem: SecItemClient = SystemSecItemClient()) {
        self.secItem = secItem
    }

    func loadData(service: String, account: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        let (status, data) = secItem.copyMatching(query)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data else {
            throw KeychainError(status: status)
        }
        return data
    }

    func saveData(_ data: Data, service: String, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = secItem.update(query, attributes: attributes)
        if updateStatus == errSecItemNotFound {
            var insert = query
            attributes.forEach { insert[$0.key] = $0.value }
            let insertStatus = secItem.add(insert)
            guard insertStatus == errSecSuccess else { throw KeychainError(status: insertStatus) }
        } else if updateStatus != errSecSuccess {
            throw KeychainError(status: updateStatus)
        }
    }

    func removeData(service: String, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = secItem.delete(query)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

private struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)"
    }
}
