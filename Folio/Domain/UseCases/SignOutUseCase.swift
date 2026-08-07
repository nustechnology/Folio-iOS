import Foundation

protocol SignOutUseCaseProtocol {
    func execute()
    func executeAwaitingCancellation() async
}

final class SignOutUseCase: SignOutUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute() {
        authRepository.signOut()
    }

    func executeAwaitingCancellation() async {
        await authRepository.signOutAwaitingCancellation()
    }
}

extension SignOutUseCaseProtocol {
    func executeAwaitingCancellation() async { execute() }
}
