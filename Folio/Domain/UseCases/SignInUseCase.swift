import Foundation

protocol SignInUseCaseProtocol {
    func execute(email: String, password: String) async throws -> AuthToken
}

final class SignInUseCase: SignInUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute(email: String, password: String) async throws -> AuthToken {
        try await authRepository.signIn(email: email, password: password)
    }
}
