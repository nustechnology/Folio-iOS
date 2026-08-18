import Foundation

struct RetryPolicy: Sendable {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let multiplier: Double
    let jitter: TimeInterval

    init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1,
        multiplier: Double = 2,
        jitter: TimeInterval = 0.25
    ) {
        self.maxRetries = max(0, maxRetries)
        self.baseDelay = max(0, baseDelay)
        self.multiplier = max(1, multiplier)
        self.jitter = max(0, jitter)
    }

    func delay(forRetry retry: Int, randomJitter: TimeInterval? = nil) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(multiplier, Double(max(0, retry)))
        let additionalJitter = randomJitter ?? Double.random(in: 0...jitter)
        return exponentialDelay + max(0, min(jitter, additionalJitter))
    }
}

actor CircuitBreaker {
    enum State: Equatable {
        case closed
        case open
        case halfOpen
    }

    private(set) var state: State = .closed
    private var failureCount = 0
    private var openedAt: Date?
    private var halfOpenProbeInFlight = false
    private let failureThreshold: Int
    private let resetTimeout: TimeInterval
    private let clock: () -> Date

    init(
        failureThreshold: Int = 5,
        resetTimeout: TimeInterval = 30,
        clock: @escaping () -> Date = Date.init
    ) {
        self.failureThreshold = max(1, failureThreshold)
        self.resetTimeout = max(0, resetTimeout)
        self.clock = clock
    }

    func shouldAllowRequest() -> Bool {
        switch state {
        case .closed:
            return true
        case .open:
            guard let openedAt, clock().timeIntervalSince(openedAt) >= resetTimeout else {
                return false
            }
            state = .halfOpen
            halfOpenProbeInFlight = true
            return true
        case .halfOpen:
            guard !halfOpenProbeInFlight else { return false }
            halfOpenProbeInFlight = true
            return true
        }
    }

    func recordSuccess() {
        state = .closed
        failureCount = 0
        openedAt = nil
        halfOpenProbeInFlight = false
    }

    func recordFailure() {
        if state == .halfOpen {
            open()
            return
        }

        failureCount += 1
        if failureCount >= failureThreshold {
            open()
        }
    }

    func releaseHalfOpenProbe() {
        if state == .halfOpen {
            halfOpenProbeInFlight = false
        }
    }

    private func open() {
        state = .open
        openedAt = clock()
        halfOpenProbeInFlight = false
    }
}

actor TokenRefreshActor {
    private var inFlight: Task<String, Error>?
    private var inFlightGeneration = 0

    func cancel(tokenProvider: AccessTokenProvider) async {
        guard let task = inFlight else {
            tokenProvider.cancelRefresh()
            return
        }
        let generation = inFlightGeneration
        task.cancel()
        tokenProvider.cancelRefresh()
        _ = try? await task.value
        if inFlightGeneration == generation {
            inFlight = nil
        }
    }

    func refresh(tokenProvider: AccessTokenProvider) async throws -> String {
        if let inFlight {
            return try await inFlight.value
        }

        inFlightGeneration += 1
        let generation = inFlightGeneration
        let task = Task {
            try await tokenProvider.refreshToken()
        }
        inFlight = task
        defer {
            if inFlightGeneration == generation {
                inFlight = nil
            }
        }
        return try await task.value
    }
}

final class NetworkService: NetworkServiceProtocol {
    private enum Constants {
        static let authenticationPathPrefix = "/api/v1/auth/"
        static let cacheMemoryCapacity = 10 * 1_024 * 1_024
        static let cacheDiskCapacity = 50 * 1_024 * 1_024
        static let defaultRequestTimeout: TimeInterval = 15
        static let defaultResourceTimeout: TimeInterval = 30
        static let authRequestTimeout: TimeInterval = 10
        static let authResourceTimeout: TimeInterval = 15
        static let uploadRequestTimeout: TimeInterval = 30
        static let uploadResourceTimeout: TimeInterval = 120
    }

    private struct Sessions {
        let defaultSession: URLSession
        let authSession: URLSession
        let uploadSession: URLSession
    }

    private static let sharedSessions: Sessions = {
        URLCache.shared = URLCache(
            memoryCapacity: Constants.cacheMemoryCapacity,
            diskCapacity: Constants.cacheDiskCapacity
        )
        return makeSessions()
    }()

    private let baseURL: URL
    private let accessTokenProvider: AccessTokenProvider?
    private let injectedSession: URLSession?
    private let sessions: Sessions?
    private let retryPolicy: RetryPolicy
    private let circuitBreaker: CircuitBreaker
    private let tokenRefreshActor = TokenRefreshActor()

    init(
        baseURL: URL,
        session: URLSession? = nil,
        accessTokenProvider: AccessTokenProvider? = nil,
        retryPolicy: RetryPolicy = .init(),
        circuitBreaker: CircuitBreaker = CircuitBreaker()
    ) {
        self.baseURL = baseURL
        self.accessTokenProvider = accessTokenProvider
        self.injectedSession = session
        self.retryPolicy = retryPolicy
        self.circuitBreaker = circuitBreaker

        self.sessions = session == nil ? Self.sharedSessions : nil
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let data = try await withRetry(endpoint: endpoint) {
            try await self.perform(endpoint)
        }
        do {
            let decoded = try Self.decoder.decode(T.self, from: data)
            await circuitBreaker.recordSuccess()
            return decoded
        } catch {
            await circuitBreaker.releaseHalfOpenProbe()
            Logger.error("Decoding error: \(error)")
            throw NetworkError.decodingError(error)
        }
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {
        _ = try await withRetry(endpoint: endpoint) {
            try await self.perform(endpoint)
        }
        await circuitBreaker.recordSuccess()
    }

    func cancelPendingRefresh() {
        guard let accessTokenProvider else { return }
        Task {
            await tokenRefreshActor.cancel(tokenProvider: accessTokenProvider)
        }
    }

    func cancelPendingRefreshAndWait() async {
        guard let accessTokenProvider else { return }
        await tokenRefreshActor.cancel(tokenProvider: accessTokenProvider)
    }

    private func withRetry(
        endpoint: APIEndpoint,
        operation: @escaping () async throws -> Data
    ) async throws -> Data {
        guard await circuitBreaker.shouldAllowRequest() else {
            throw NetworkError.circuitBreakerOpen
        }

        var retry = 0
        while true {
            do {
                let data = try await operation()
                return data
            } catch {
                guard endpoint.allowsAutomaticRetry,
                      Self.isTransientError(error),
                      retry < retryPolicy.maxRetries else {
                    if Self.isTransientError(error) {
                        await circuitBreaker.recordFailure()
                    } else if Self.isHTTPResponseError(error) {
                        await circuitBreaker.recordSuccess()
                    } else {
                        await circuitBreaker.releaseHalfOpenProbe()
                    }
                    throw error
                }

                let delay = retryPolicy.delay(forRetry: retry)
                #if DEBUG
                Logger.debug(
                    "Retrying request (attempt \(retry + 1)/\(retryPolicy.maxRetries), delay: \(delay)s): "
                        + error.localizedDescription
                )
                #endif
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    await circuitBreaker.releaseHalfOpenProbe()
                    throw error
                }
                retry += 1
            }
        }
    }

    private func perform(_ endpoint: APIEndpoint, allowTokenRefresh: Bool = true) async throws -> Data {
        guard baseURL.scheme == "https" else {
            throw NetworkError.insecureURL
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: true
        )
        components?.queryItems = endpoint.queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.cachePolicy = injectedSession == nil ? endpoint.cachePolicy : .reloadIgnoringLocalCacheData
        request.setValue(endpoint.contentType, forHTTPHeaderField: "Content-Type")
        endpoint.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if endpoint.requiresAuthentication {
            guard let accessToken = accessTokenProvider?.accessToken, !accessToken.isEmpty else {
                throw NetworkError.missingAuthenticationToken
            }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        Logger.debug("→ \(endpoint.method.rawValue) \(url.absoluteString)")
        let (data, response) = try await selectedSession(for: endpoint).data(
            for: request,
            delegate: RedirectDelegate(allowedOrigin: url)
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        #if DEBUG
        logResponse(
            method: endpoint.method.rawValue,
            path: endpoint.path,
            statusCode: httpResponse.statusCode,
            data: data
        )
        #endif

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
            guard httpResponse.statusCode == 401,
                  endpoint.requiresAuthentication,
                  allowTokenRefresh,
                  let tokenProvider = accessTokenProvider,
                  !endpoint.path.hasPrefix(Constants.authenticationPathPrefix) else {
                throw error
            }

            return try await retryAfterTokenRefresh(endpoint, tokenProvider: tokenProvider)
        }

        return data
    }

    private func retryAfterTokenRefresh(
        _ endpoint: APIEndpoint,
        tokenProvider: AccessTokenProvider
    ) async throws -> Data {
        do {
            _ = try await tokenRefreshActor.refresh(tokenProvider: tokenProvider)
        } catch let refreshError {
            if case NetworkError.httpError(let statusCode, _) = refreshError,
               statusCode == 401 || statusCode == 403 {
                await tokenRefreshActor.cancel(tokenProvider: tokenProvider)
                do {
                    try tokenProvider.invalidateSession()
                } catch {
                    Logger.error("Failed to invalidate session after token refresh returned \(statusCode): \(error)")
                }
            }
            throw refreshError
        }

        do {
            return try await perform(endpoint, allowTokenRefresh: false)
        } catch let retryError as NetworkError {
            if case .httpError(let statusCode, _) = retryError, statusCode == 401 {
                do {
                    try tokenProvider.invalidateSession()
                } catch {
                    Logger.error("Failed to invalidate session after retry returned \(statusCode): \(error)")
                }
            }
            throw retryError
        }
    }

    private func selectedSession(for endpoint: APIEndpoint) -> URLSession {
        if let injectedSession {
            return injectedSession
        }
        guard let sessions else {
            preconditionFailure("Default sessions are unavailable without an injected session")
        }
        if endpoint.path.hasPrefix(Constants.authenticationPathPrefix) {
            return sessions.authSession
        }
        if endpoint.contentType.hasPrefix("multipart/form-data") {
            return sessions.uploadSession
        }
        return sessions.defaultSession
    }

    private static func makeSessions() -> Sessions {
        func make(requestTimeout: TimeInterval, resourceTimeout: TimeInterval) -> URLSession {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = requestTimeout
            configuration.timeoutIntervalForResource = resourceTimeout
            configuration.waitsForConnectivity = true
            configuration.urlCache = URLCache.shared
            configuration.requestCachePolicy = .useProtocolCachePolicy
            return URLSession(configuration: configuration)
        }

        return Sessions(
            defaultSession: make(
                requestTimeout: Constants.defaultRequestTimeout,
                resourceTimeout: Constants.defaultResourceTimeout
            ),
            authSession: make(
                requestTimeout: Constants.authRequestTimeout,
                resourceTimeout: Constants.authResourceTimeout
            ),
            uploadSession: make(
                requestTimeout: Constants.uploadRequestTimeout,
                resourceTimeout: Constants.uploadResourceTimeout
            )
        )
    }

    static func isTransientError(_ error: Error) -> Bool {
        if let error = error as? NetworkError, case .httpError(let statusCode, _) = error {
            return [408, 429, 500, 502, 503, 504].contains(statusCode)
        }
        if let error = error as? URLError {
            return [
                .timedOut,
                .networkConnectionLost,
                .cannotConnectToHost,
                .dnsLookupFailed,
                .notConnectedToInternet
            ].contains(error.code)
        }
        return false
    }

    static func isHTTPResponseError(_ error: Error) -> Bool {
        if let error = error as? NetworkError, case .httpError = error {
            return true
        }
        return false
    }

    #if DEBUG
    private func logResponse(method: String, path: String, statusCode: Int, data: Data) {
        let label = (200...299).contains(statusCode) ? "[OK]" : "[ERR]"
        Logger.debug("\(label) \(method) \(path) → \(statusCode)")
        guard !path.hasPrefix(Constants.authenticationPathPrefix),
              let json = data.prettyJSON else { return }
        Logger.debug("[BODY]\n\(json)")
    }
    #endif

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            let value = try container.decode(String.self)
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [
                .withInternetDateTime,
                .withDashSeparatorInDate,
                .withColonSeparatorInTime,
                .withTimeZone,
                .withFractionalSeconds
            ]
            let standardFormatter = ISO8601DateFormatter()
            if let date = fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported date format")
        }
        return decoder
    }()
}

enum NetworkError: LocalizedError {
    case invalidURL
    case insecureURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data? = nil)
    case decodingError(Error)
    case missingAuthenticationToken
    case tokenRefreshUnavailable
    case circuitBreakerOpen

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "Invalid URL")
        case .insecureURL:
            return String(localized: "Non-HTTPS connections are not permitted")
        case .invalidResponse:
            return String(localized: "Invalid response from server")
        case .httpError(let statusCode, let data):
            if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                return message
            }
            return String(format: String(localized: "HTTP error with status code %lld"), statusCode)
        case .decodingError(let error):
            return String(format: String(localized: "Failed to decode response: %@"), error.localizedDescription)
        case .missingAuthenticationToken:
            return String(localized: "Authentication token is missing")
        case .tokenRefreshUnavailable:
            return String(localized: "Authentication refresh is unavailable")
        case .circuitBreakerOpen:
            return String(localized: "The service is temporarily unavailable. Please try again shortly.")
        }
    }

    var errorData: Data? {
        if case .httpError(_, let data) = self { return data }
        return nil
    }
}

final class RedirectDelegate: NSObject, URLSessionTaskDelegate {
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

extension Data {
    fileprivate var prettyJSON: String? {
        guard let json = try? JSONSerialization.jsonObject(with: self),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let string = String(data: pretty, encoding: .utf8)
        else { return nil }
        return string
    }
}
