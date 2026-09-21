import Foundation

protocol GetStoredAuthSessionUseCaseProtocol {
    func execute() -> AuthToken?
}

final class GetStoredAuthSessionUseCase: GetStoredAuthSessionUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute() -> AuthToken? {
        authRepository.getStoredSession()
    }
}
