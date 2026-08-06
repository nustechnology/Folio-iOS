import Foundation

protocol UserRepositoryProtocol {
    func fetchUsers() async throws -> [User]
    func fetchMe() async throws -> UserIdentity
}
