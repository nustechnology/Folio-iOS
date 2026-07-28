import Foundation

protocol LocalStorageProtocol {
    func save<T: Codable>(_ value: T, forKey key: String) throws
    func load<T: Codable>(forKey key: String) throws -> T?
    func remove(forKey key: String)
    func clear()
}
