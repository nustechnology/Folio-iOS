import Foundation

protocol AccessTokenProvider: Sendable {
    var accessToken: String? { get }
    func refreshToken() async throws -> String
    nonisolated func cancelRefresh()
    func invalidateSession()
}

extension AccessTokenProvider {
    func refreshToken() async throws -> String {
        throw NetworkError.tokenRefreshUnavailable
    }

    nonisolated func cancelRefresh() {}
    func invalidateSession() {}
}

struct SessionAccessTokenProvider: AccessTokenProvider {
    private let localStorage: LocalStorageProtocol
    private let baseURL: URL

    init(localStorage: LocalStorageProtocol, baseURL: URL) {
        self.localStorage = localStorage
        self.baseURL = baseURL
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

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = true
        let (data, response) = try await URLSession(configuration: configuration).data(
            for: request,
            delegate: RedirectDelegate(allowedOrigin: request.url!)
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                localStorage.remove(forKey: StorageKey.authSession)
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

    func invalidateSession() {
        localStorage.remove(forKey: StorageKey.authSession)
    }
}
