import Foundation

protocol SignUpUseCaseProtocol {
    func execute(name: String, email: String, password: String) async throws -> AuthToken
}

final class SignUpUseCase: SignUpUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute(name: String, email: String, password: String) async throws -> AuthToken {
        try await authRepository.signUp(name: name, email: email, password: password)
    }
}
