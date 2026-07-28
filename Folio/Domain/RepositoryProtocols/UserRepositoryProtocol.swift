import Foundation

protocol UserRepositoryProtocol {
    func fetchUsers() async throws -> [User]
}
