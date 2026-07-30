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
            saveSession(token)
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
            saveSession(token)
            return token
        } catch let error as NetworkError {
            throw mapAuthError(error)
        }
    }

    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        do {
            let existingUser = loadSession()
            let response: AuthResponseDTO = try await networkService.request(
                AuthEndpoint.refreshToken(refreshToken: refreshToken)
            )
            var token = response.toDomain()
            if token.userName == nil, token.userEmail == nil {
                token = AuthToken(
                    accessToken: token.accessToken,
                    refreshToken: token.refreshToken,
                    expiresAt: token.expiresAt,
                    userName: existingUser?.userName,
                    userEmail: existingUser?.userEmail
                )
            }
            saveSession(token)
            return token
        } catch let error as NetworkError {
            throw mapAuthError(error)
        }
    }

    func signOut() {
        localStorage.remove(forKey: "auth_session")
    }

    func getCurrentSession() -> AuthToken? {
        guard let session = loadSession(), session.isValid else {
            return nil
        }
        return session
    }

    private func saveSession(_ token: AuthToken) {
        try? localStorage.save(token.toDTO(), forKey: "auth_session")
    }

    private func loadSession() -> AuthToken? {
        guard let dto: AuthTokenDTO = try? localStorage.load(forKey: "auth_session") else {
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
