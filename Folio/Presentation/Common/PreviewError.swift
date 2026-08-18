import Foundation

enum PreviewError: Error {
    case unavailable
}

final class PreviewStorage: LocalStorageProtocol {
    private var values: [String: Data] = [:]

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        values[key] = try JSONEncoder().encode(value)
    }

    func load<T: Codable>(forKey key: String) throws -> T? {
        guard let data = values[key] else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func remove(forKey key: String) throws {
        values.removeValue(forKey: key)
    }

}
