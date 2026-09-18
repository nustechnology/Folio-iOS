import Foundation

enum PreviewError: Error {
    case unavailable
}

struct PreviewGetStoredAuthSessionUseCase: GetStoredAuthSessionUseCaseProtocol {
    var session: AuthToken?

    func execute() -> AuthToken? { session }
}
