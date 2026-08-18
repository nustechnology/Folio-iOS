import Foundation

final class AuthRepository: AuthRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    private let localStorage: LocalStorageProtocol

    init(networkService: NetworkServiceProtocol, localStorage: LocalStorageProtocol) {
        self.networkService = networkService
        self.localStorage = localStorage
    }

    func signUp(name: String, email: String, password: String) async throws -> AuthToken {
        do {
            let response: AuthResponseDTO = try await networkService.request(
                AuthEndpoint.signUp(name: name, email: email, password: password, confirmPassword: password)
            )
            let token = response.toDomain()
            try saveSession(token)
            return token
        } catch let error as NetworkError {
            throw mapAuthError(error)
        }
    }

    func signIn(email: String, password: String) async throws -> AuthToken {
        do {
            let response: AuthResponseDTO = try await networkService.request(
                AuthEndpoint.signIn(email: email, password: password)
            )
            let token = response.toDomain()
            try saveSession(token)
            return token
        } catch let error as NetworkError {
            throw mapAuthError(error)
        }
    }

    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        do {
            let response: AuthResponseDTO = try await networkService.request(
                AuthEndpoint.refreshToken(refreshToken: refreshToken)
            )
            let token = response.toDomain()
            try saveSession(token)
            return token
        } catch let error as NetworkError {
            throw mapAuthError(error)
        }
    }

    func signOut() throws {
        do {
            try localStorage.remove(forKey: StorageKey.authSession)
        } catch {
            throw AuthError.sessionRemovalFailed
        }
        networkService.cancelPendingRefresh()
    }

    func signOutAwaitingCancellation() async throws {
        do {
            try localStorage.remove(forKey: StorageKey.authSession)
        } catch {
            throw AuthError.sessionRemovalFailed
        }
        await networkService.cancelPendingRefreshAndWait()
    }

    func getCurrentSession() -> AuthToken? {
        guard let session = loadSession(), session.isValid else {
            return nil
        }
        return session
    }

    private func saveSession(_ token: AuthToken) throws {
        do {
            try localStorage.save(token.toDTO(), forKey: StorageKey.authSession)
        } catch {
            do {
                try localStorage.remove(forKey: StorageKey.authSession)
            } catch {
                throw AuthError.sessionPersistenceFailed
            }
            throw AuthError.sessionPersistenceFailed
        }
    }

    private func loadSession() -> AuthToken? {
        guard let dto: AuthTokenDTO = try? localStorage.load(forKey: StorageKey.authSession) else {
            return nil
        }
        return dto.toDomain()
    }

    private func mapAuthError(_ error: NetworkError) -> AuthError {
        let apiMessage = parseErrorMessage(error.errorData)

        switch error {
        case .httpError(let statusCode, _):
            switch statusCode {
            case 409: return .emailAlreadyExists
            case 401: return .invalidCredentials
            case 400:
                if let message = apiMessage {
                    return .networkError(message)
                }
                return .invalidCredentials
            default:
                return apiMessage.map { .networkError($0) } ?? .networkError("Something went wrong. Please try again.")
            }
        default:
            return .networkError(error.localizedDescription)
        }
    }

    private func parseErrorMessage(_ data: Data?) -> String? {
        guard let data,
              let errorResponse = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.message
    }
}
