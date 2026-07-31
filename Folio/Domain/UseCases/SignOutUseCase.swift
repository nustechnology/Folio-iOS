import Foundation

protocol SignOutUseCaseProtocol {
    func execute()
}

final class SignOutUseCase: SignOutUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute() {
        authRepository.signOut()
    }
}
