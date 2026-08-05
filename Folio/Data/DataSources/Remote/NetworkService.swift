import Foundation

final class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let baseURL: URL
    private let accessTokenProvider: AccessTokenProvider?
    private let refreshCoordinator: SessionRefreshCoordinator?
    private let onSessionInvalidated: (@Sendable () -> Void)?
    private let sleep: @Sendable (UInt64) async throws -> Void
    private let random: @Sendable (ClosedRange<Double>) -> Double

    init(
        baseURL: URL,
        session: URLSession = .shared,
        accessTokenProvider: AccessTokenProvider? = nil,
        refreshSession: (@Sendable (String) async throws -> Void)? = nil,
        onSessionInvalidated: (@Sendable () -> Void)? = nil,
        sleep: @escaping @Sendable (UInt64) async throws -> Void = { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        },
        random: @escaping @Sendable (ClosedRange<Double>) -> Double = { range in
            Double.random(in: range)
        }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessTokenProvider = accessTokenProvider
        self.onSessionInvalidated = onSessionInvalidated
        self.refreshCoordinator = refreshSession.map { refreshSession in
            SessionRefreshCoordinator(
                refreshSession: refreshSession,
                clearSession: {
                    await accessTokenProvider?.clearSession()
                    onSessionInvalidated?()
                }
            )
        }
        self.sleep = sleep
        self.random = random
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
        let policy = endpoint.resiliencePolicy
        var attempt = 1
        var didRefresh = false

        while true {
            do {
                return try await performOnce(endpoint, policy: policy)
            } catch let failure as TransportFailure {
                if failure.error.isUnauthorized,
                   endpoint.requiresAuthentication,
                   !didRefresh {
                    try await refreshAccessToken(observedAccessToken: failure.accessToken)
                    didRefresh = true
                    continue
                }

                if failure.error.isUnauthorized, endpoint.requiresAuthentication {
                    // A retry can finish after another request has already refreshed
                    // the session again. Never clear credentials newer than the token
                    // used by this failed request.
                    if accessTokenProvider?.accessToken == failure.accessToken {
                        invalidateSession()
                    }
                    throw NetworkError.unauthorized
                }

                guard attempt < policy.maximumAttempts,
                      policy.isRetryable,
                      failure.error.isRetryable else {
                    throw failure.error
                }

                let delay = retryDelay(for: attempt, policy: policy, retryAfter: failure.retryAfter)
                guard let delay else { throw failure.error }
                Logger.debug("Retrying \(endpoint.method.rawValue) request after \(delay)s (attempt \(attempt + 1))")
                try await sleep(UInt64(delay * 1_000_000_000))
                try Task.checkCancellation()
                attempt += 1
            } catch let cancellation as CancellationError {
                throw cancellation
            } catch {
                throw classify(error)
            }
        }
    }

    private func refreshAccessToken(observedAccessToken: String?) async throws {
        guard let refreshToken = accessTokenProvider?.refreshToken,
              !refreshToken.isEmpty,
              let refreshCoordinator else {
            accessTokenProvider?.clearSession()
            onSessionInvalidated?()
            throw NetworkError.unauthorized
        }
        try await refreshCoordinator.refresh(
            refreshToken: refreshToken,
            observedAccessToken: observedAccessToken
        )
    }

    private func invalidateSession() {
        accessTokenProvider?.clearSession()
        onSessionInvalidated?()
    }

    private func performOnce(_ endpoint: APIEndpoint, policy: EndpointResiliencePolicy) async throws -> Data {
        guard baseURL.scheme == "https" else {
            throw NetworkError.insecureURL
        }

        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)
        components?.queryItems = endpoint.queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = policy.requestTimeout
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue(endpoint.contentType, forHTTPHeaderField: "Content-Type")
        endpoint.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let accessToken = accessTokenProvider?.accessToken
        if endpoint.requiresAuthentication,
           let accessToken,
           !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        Logger.debug("→ \(endpoint.method.rawValue) \(url.absoluteString)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
                group.addTask {
                    try await self.session.data(for: request, delegate: RedirectDelegate(allowedOrigin: url))
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(policy.resourceTimeout * 1_000_000_000))
                    throw NetworkError.timeout
                }
                defer { group.cancelAll() }
                return try await group.next()!
            }
        } catch {
            if error is CancellationError {
                throw error
            }
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            throw TransportFailure(error: classify(error), retryAfter: nil)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransportFailure(error: .invalidResponse, retryAfter: nil)
        }

        Logger.debug("← \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TransportFailure(
                error: .httpError(statusCode: httpResponse.statusCode, data: data),
                retryAfter: retryAfter(from: httpResponse),
                accessToken: accessToken
            )
        }

        return data
    }

    private func retryDelay(
        for attempt: Int,
        policy: EndpointResiliencePolicy,
        retryAfter: TimeInterval?
    ) -> TimeInterval? {
        if let retryAfter, retryAfter >= 0 {
            if retryAfter > policy.maximumRetryAfter {
                return nil
            }
            return retryAfter
        }

        let exponential = min(
            policy.maximumBackoff,
            policy.baseBackoff * pow(2, Double(max(0, attempt - 1)))
        )
        let jitter = exponential * random(0...policy.jitterFraction)
        return min(policy.maximumBackoff, exponential + jitter)
    }

    private func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        if let seconds = TimeInterval(value), seconds >= 0 { return seconds }
        guard let date = HTTPDateFormatter.shared.date(from: value) else { return nil }
        return max(0, date.timeIntervalSinceNow)
    }

    private func classify(_ error: Error) -> NetworkError {
        if let error = error as? NetworkError { return error }
        guard let urlError = error as? URLError else {
            return .transportError(error.localizedDescription)
        }
        switch urlError.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
            return .offline
        case .cancelled:
            return .cancelled
        default:
            return .transportError(urlError.localizedDescription)
        }
    }
}

private struct TransportFailure: Error {
    let error: NetworkError
    let retryAfter: TimeInterval?
    let accessToken: String?

    init(error: NetworkError, retryAfter: TimeInterval?, accessToken: String? = nil) {
        self.error = error
        self.retryAfter = retryAfter
        self.accessToken = accessToken
    }
}

private actor SessionRefreshCoordinator {
    private let refreshSession: @Sendable (String) async throws -> Void
    private let clearSession: @Sendable () async -> Void
    private var refreshTask: Task<Void, Error>?
    private var lastRefreshedAccessToken: String?

    init(
        refreshSession: @escaping @Sendable (String) async throws -> Void,
        clearSession: @escaping @Sendable () async -> Void
    ) {
        self.refreshSession = refreshSession
        self.clearSession = clearSession
    }

    func refresh(refreshToken: String, observedAccessToken: String?) async throws {
        if let observedAccessToken,
           observedAccessToken == lastRefreshedAccessToken {
            return
        }
        if let refreshTask {
            try await refreshTask.value
            return
        }

        let task = Task {
            try await refreshSession(refreshToken)
        }
        refreshTask = task

        do {
            try await task.value
            refreshTask = nil
            lastRefreshedAccessToken = observedAccessToken
        } catch {
            refreshTask = nil
            if isDefinitiveRefreshFailure(error) {
                await clearSession()
            }
            throw error
        }
    }

    private func isDefinitiveRefreshFailure(_ error: Error) -> Bool {
        if let error = error as? AuthError {
            switch error {
            case .invalidCredentials, .sessionExpired:
                return true
            case .invalidEmail, .emailAlreadyExists, .passwordTooShort, .passwordsDoNotMatch, .networkError:
                return false
            }
        }
        if let error = error as? NetworkError {
            if case .unauthorized = error { return true }
            if case .httpError(let statusCode, _) = error {
                return statusCode == 401
            }
        }
        return false
    }
}

private final class HTTPDateFormatter {
    static let shared = HTTPDateFormatter()
    private let formatter: DateFormatter

    private init() {
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    }

    func date(from string: String) -> Date? {
        formatter.date(from: string)
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case insecureURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data? = nil)
    case decodingError(Error)
    case timeout
    case offline
    case cancelled
    case transportError(String)
    case unauthorized

    var isRetryable: Bool {
        switch self {
        case .timeout, .offline, .transportError:
            return true
        case .httpError(let statusCode, _):
            return [408, 425, 429, 500, 502, 503, 504].contains(statusCode)
        case .invalidURL, .insecureURL, .invalidResponse, .decodingError, .cancelled, .unauthorized:
            return false
        }
    }

    var isUnauthorized: Bool {
        if case .httpError(let statusCode, _) = self {
            return statusCode == 401
        }
        return false
    }

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
        case .timeout:
            return String(localized: "The request timed out")
        case .offline:
            return String(localized: "No network connection")
        case .cancelled:
            return String(localized: "The request was cancelled")
        case .transportError(let message):
            return message
        case .unauthorized:
            return String(localized: "Authentication is no longer valid")
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
