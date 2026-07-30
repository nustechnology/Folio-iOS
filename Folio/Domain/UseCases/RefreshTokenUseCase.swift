import Foundation

protocol RefreshTokenUseCaseProtocol {
    func execute(refreshToken: String) async throws -> AuthToken
}

final class RefreshTokenUseCase: RefreshTokenUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute(refreshToken: String) async throws -> AuthToken {
        try await authRepository.refreshToken(refreshToken)
    }
}
