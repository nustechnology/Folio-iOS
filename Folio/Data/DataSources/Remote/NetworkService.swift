import Foundation

final class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let baseURL: URL
    private let accessTokenProvider: AccessTokenProvider?

    init(
        baseURL: URL,
        session: URLSession = .shared,
        accessTokenProvider: AccessTokenProvider? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessTokenProvider = accessTokenProvider
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let data = try await perform(endpoint)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            let value = try container.decode(String.self)
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withTimeZone, .withFractionalSeconds]
            let standardFormatter = ISO8601DateFormatter()
            if let date = fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported date format")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Logger.error("Decoding error: \(error)")
            throw NetworkError.decodingError(error)
        }
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {
        _ = try await perform(endpoint)
    }

    private func perform(_ endpoint: APIEndpoint) async throws -> Data {
        guard baseURL.scheme == "https" else {
            throw NetworkError.insecureURL
        }

        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)
        components?.queryItems = endpoint.queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue(endpoint.contentType, forHTTPHeaderField: "Content-Type")
        endpoint.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if endpoint.requiresAuthentication,
           let accessToken = accessTokenProvider?.accessToken,
           !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        Logger.debug("→ \(endpoint.method.rawValue) \(url.absoluteString)")

        let (data, response) = try await session.data(for: request, delegate: RedirectDelegate(allowedOrigin: url))

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        Logger.debug("← \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case insecureURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data? = nil)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .insecureURL:
            return "Non-HTTPS connections are not permitted"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, _):
            return "HTTP error with status code \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }

    var errorData: Data? {
        if case .httpError(_, let data) = self { return data }
        return nil
    }
}

private final class RedirectDelegate: NSObject, URLSessionTaskDelegate {
    let allowedOrigin: URL

    init(allowedOrigin: URL) {
        self.allowedOrigin = allowedOrigin
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @Sendable @escaping (URLRequest?) -> Void
    ) {
        guard let destination = request.url,
              destination.scheme == allowedOrigin.scheme,
              destination.host == allowedOrigin.host,
              destination.effectivePort == allowedOrigin.effectivePort else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

extension URL {
    fileprivate var effectivePort: Int {
        guard let explicit = port else {
            if scheme == "http" { return 80 }
            if scheme == "https" { return 443 }
            return 0
        }
        return explicit
    }
}
