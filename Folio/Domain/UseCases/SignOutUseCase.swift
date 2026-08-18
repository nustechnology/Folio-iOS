import Foundation

protocol SignOutUseCaseProtocol {
    func execute() throws
    func executeAwaitingCancellation() async throws
}

final class SignOutUseCase: SignOutUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute() throws {
        try authRepository.signOut()
    }

    func executeAwaitingCancellation() async throws {
        try await authRepository.signOutAwaitingCancellation()
    }
}

extension SignOutUseCaseProtocol {
    func executeAwaitingCancellation() async throws { try execute() }
}
