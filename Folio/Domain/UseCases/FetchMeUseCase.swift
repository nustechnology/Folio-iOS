import Foundation

protocol FetchMeUseCaseProtocol {
    func execute() async throws -> UserIdentity
}

final class FetchMeUseCase: FetchMeUseCaseProtocol {
    private let userRepository: UserRepositoryProtocol

    init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }

    func execute() async throws -> UserIdentity {
        try await userRepository.fetchMe()
    }
}
