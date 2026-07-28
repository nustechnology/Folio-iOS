import Foundation

final class UserRepository: UserRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    private let localStorage: LocalStorageProtocol

    init(networkService: NetworkServiceProtocol, localStorage: LocalStorageProtocol) {
        self.networkService = networkService
        self.localStorage = localStorage
    }

    func fetchUsers() async throws -> [User] {
        let dtos: [UserDTO] = try await networkService.request(UserEndpoint.getUsers)
        let users = dtos.map { $0.toDomain() }
        try? localStorage.save(dtos, forKey: "cached_users")
        return users
    }
}
