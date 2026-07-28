import Foundation

protocol FetchUsersUseCaseProtocol {
    func execute() async throws -> [User]
}

final class FetchUsersUseCase: FetchUsersUseCaseProtocol {
    private let userRepository: UserRepositoryProtocol

    init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }

    func execute() async throws -> [User] {
        try await userRepository.fetchUsers()
    }
}
