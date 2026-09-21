import Foundation

protocol AccessTokenProvider: Sendable {
    var accessToken: String? { get }
    func refreshToken() async throws -> String
    nonisolated func cancelRefresh()
    func invalidateSession() throws
}

extension AccessTokenProvider {
    func refreshToken() async throws -> String {
        throw NetworkError.tokenRefreshUnavailable
    }

    nonisolated func cancelRefresh() {}
    func invalidateSession() throws {}
}

struct SessionAccessTokenProvider: AccessTokenProvider {
    private let localStorage: LocalStorageProtocol
    private let baseURL: URL
    private let urlSession: URLSession

    init(localStorage: LocalStorageProtocol, baseURL: URL, session: URLSession? = nil) {
        self.localStorage = localStorage
        self.baseURL = baseURL
        if let session {
            self.urlSession = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 10
            configuration.timeoutIntervalForResource = 15
            configuration.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: configuration)
        }
    }

    var accessToken: String? {
        guard let session: AuthTokenDTO = try? localStorage.load(forKey: StorageKey.authSession) else {
            return nil
        }
        return session.accessToken
    }

    func refreshToken() async throws -> String {
        guard let session: AuthTokenDTO = try? localStorage.load(forKey: StorageKey.authSession) else {
            throw NetworkError.missingAuthenticationToken
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/auth/refresh"))
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["refreshToken": session.refreshToken])
        request.timeoutInterval = 10

        let (data, response) = try await urlSession.data(
            for: request,
            delegate: RedirectDelegate(allowedOrigin: request.url!)
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                do {
                    try removeSession()
                } catch {
                    Logger.error("Failed to remove session after refresh returned \(httpResponse.statusCode): \(error)")
                }
            }
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let token = try decoder.decode(AuthResponseDTO.self, from: data).toDomain()
        try localStorage.save(token.toDTO(), forKey: StorageKey.authSession)
        return token.accessToken
    }

    nonisolated func cancelRefresh() {}

    func invalidateSession() throws {
        try removeSession()
    }

    private func removeSession() throws {
        do {
            try localStorage.remove(forKey: StorageKey.authSession)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .didInvalidateSession, object: nil)
            }
        } catch {
            throw AuthError.sessionRemovalFailed
        }
    }
}

extension Notification.Name {
    static let didInvalidateSession = Notification.Name("didInvalidateSession")
}
