import Foundation

protocol RequestPasswordResetUseCaseProtocol {
    func execute(email: String) async throws
}

final class RequestPasswordResetUseCase: RequestPasswordResetUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute(email: String) async throws {
        try await authRepository.requestPasswordReset(email: email)
    }
}
