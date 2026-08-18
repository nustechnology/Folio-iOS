@testable import Folio
import Foundation
import XCTest

final class NetworkResilienceTests: XCTestCase {
    func testRetryPolicyUsesExponentialDelayWithoutJitter() {
        let policy = RetryPolicy(maxRetries: 3, baseDelay: 1, multiplier: 2, jitter: 0)

        XCTAssertEqual(policy.delay(forRetry: 0), 1)
        XCTAssertEqual(policy.delay(forRetry: 1), 2)
        XCTAssertEqual(policy.delay(forRetry: 2), 4)
    }

    func testTransientErrorClassification() {
        XCTAssertTrue(NetworkService.isTransientError(URLError(.timedOut)))
        XCTAssertTrue(NetworkService.isTransientError(NetworkError.httpError(statusCode: 503)))
        XCTAssertFalse(NetworkService.isTransientError(NetworkError.httpError(statusCode: 400)))
        XCTAssertFalse(NetworkService.isTransientError(URLError(.cancelled)))
    }

    func testNetworkServiceRetriesTransientResponse() async throws {
        RetryURLProtocol.reset(statusCodes: [503, 200])
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RetryURLProtocol.self]
        let service = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration),
            accessTokenProvider: FixedResilienceTokenProvider(),
            retryPolicy: RetryPolicy(maxRetries: 1, baseDelay: 0, multiplier: 2, jitter: 0),
            circuitBreaker: CircuitBreaker(failureThreshold: 5, resetTimeout: 60)
        )

        let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))

        XCTAssertEqual(RetryURLProtocol.requestCount, 2)
    }

    func testNetworkServiceDoesNotRetryTransientMutation() async throws {
        RetryURLProtocol.reset(statusCodes: [503, 200])
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RetryURLProtocol.self]
        let service = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration),
            accessTokenProvider: FixedResilienceTokenProvider(),
            retryPolicy: RetryPolicy(maxRetries: 1, baseDelay: 0, multiplier: 2, jitter: 0),
            circuitBreaker: CircuitBreaker(failureThreshold: 5, resetTimeout: 60)
        )

        do {
            let _: WorkspaceResponseDTO = try await service.request(
                WorkspaceEndpoint.create(name: "Research", objective: "Objective")
            )
            XCTFail("Expected the mutation to fail without retrying")
        } catch NetworkError.httpError(statusCode: 503, _) {
        }

        XCTAssertEqual(RetryURLProtocol.requestCount, 1)
    }

    func testNetworkServiceRefreshesTokenAfterUnauthorizedResponse() async throws {
        AuthURLProtocol.reset()
        let provider = RefreshingTokenProvider()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocol.self]
        let service = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration),
            accessTokenProvider: provider,
            retryPolicy: RetryPolicy(maxRetries: 0)
        )

        let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))

        XCTAssertEqual(provider.refreshCount, 1)
        XCTAssertEqual(AuthURLProtocol.requestCount, 2)
        XCTAssertEqual(AuthURLProtocol.lastAuthorization, "Bearer new-token")
    }

    func testTransientTokenRefreshFailurePreservesSession() async {
        TransientRefreshURLProtocol.reset()
        let provider = FailingRefreshTokenProvider()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TransientRefreshURLProtocol.self]
        let service = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration),
            accessTokenProvider: provider,
            retryPolicy: RetryPolicy(maxRetries: 0)
        )

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected token refresh to fail")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            XCTFail("Expected a timeout, got \(error)")
        }

        XCTAssertFalse(provider.didInvalidateSession)
    }

    func testUnauthorizedTokenRefreshPreservesServerErrorWhenSessionInvalidationFails() async {
        let provider = UnauthorizedRefreshTokenProvider()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AlwaysUnauthorizedURLProtocol.self]
        let service = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration),
            accessTokenProvider: provider,
            retryPolicy: RetryPolicy(maxRetries: 0)
        )

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected token refresh to fail")
        } catch NetworkError.httpError(statusCode: 401, _) {
        } catch {
            XCTFail("Expected an unauthorized response, got \(error)")
        }
    }

    func testUnauthorizedRetryPreservesServerErrorWhenSessionInvalidationFails() async {
        let provider = FailingInvalidationTokenProvider()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AlwaysUnauthorizedURLProtocol.self]
        let service = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration),
            accessTokenProvider: provider,
            retryPolicy: RetryPolicy(maxRetries: 0)
        )

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected the retried request to fail")
        } catch NetworkError.httpError(statusCode: 401, _) {
        } catch {
            XCTFail("Expected an unauthorized response, got \(error)")
        }
    }

    func testUnauthorizedRetryInvalidatesSessionAfterRefresh() async {
        let provider = SuccessfulRefreshTokenProvider()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AlwaysUnauthorizedURLProtocol.self]
        let service = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration),
            accessTokenProvider: provider,
            retryPolicy: RetryPolicy(maxRetries: 0)
        )

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected the retried request to fail")
        } catch NetworkError.httpError(statusCode: 401, _) {
        } catch {
            XCTFail("Expected an unauthorized response, got \(error)")
        }

        XCTAssertEqual(provider.refreshCount, 1)
        XCTAssertTrue(provider.didInvalidateSession)
    }

    func testTokenRefreshActorCancelInvokesProviderCancellation() async throws {
        let provider = CancellableRefreshTokenProvider()
        let actor = TokenRefreshActor()
        let refreshTask = Task { try await actor.refresh(tokenProvider: provider) }

        let refreshStarted = await provider.waitForRefreshStart()
        XCTAssertTrue(refreshStarted)
        let cancellationTask = Task { await actor.cancel(tokenProvider: provider) }

        let cancellationStarted = await provider.waitForCancellation()
        XCTAssertTrue(cancellationStarted)
        provider.finishCancellation()
        await cancellationTask.value

        do {
            _ = try await refreshTask.value
            XCTFail("Expected the canceled refresh to fail")
        } catch is CancellationError {
        }

        XCTAssertGreaterThanOrEqual(provider.cancelCount, 1)
    }

    func testTokenRefreshActorCancelClearsInFlightRefreshForSubsequentRefresh() async throws {
        let provider = CancellableRefreshTokenProvider()
        let actor = TokenRefreshActor()
        let refreshTask = Task { try await actor.refresh(tokenProvider: provider) }

        let refreshStarted = await provider.waitForRefreshStart()
        XCTAssertTrue(refreshStarted)
        let cancellationTask = Task { await actor.cancel(tokenProvider: provider) }

        let cancellationStarted = await provider.waitForCancellation()
        XCTAssertTrue(cancellationStarted)
        provider.finishCancellation()
        await cancellationTask.value

        do {
            _ = try await refreshTask.value
            XCTFail("Expected the canceled refresh to fail")
        } catch is CancellationError {
        }
        let token = try await actor.refresh(tokenProvider: provider)

        XCTAssertEqual(token, "token-2")
        XCTAssertEqual(provider.refreshCount, 2)
    }


    func testNetworkServiceCancelPendingRefreshInvokesProviderCancellation() async {
        let provider = CancellableRefreshTokenProvider()
        let service = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            accessTokenProvider: provider
        )

        service.cancelPendingRefresh()

        let cancellationStarted = await provider.waitForCancellation()
        XCTAssertTrue(cancellationStarted)
        XCTAssertEqual(provider.cancelCount, 1)
    }

    func testNetworkServiceCancelPendingRefreshAndWaitInvokesProviderCancellation() async {
        let provider = CancellableRefreshTokenProvider()
        let service = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            accessTokenProvider: provider
        )

        await service.cancelPendingRefreshAndWait()

        XCTAssertEqual(provider.cancelCount, 1)
    }

    func testCircuitBreakerFastFailsAfterRetryExhaustion() async throws {
        CircuitURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CircuitURLProtocol.self]
        let service = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration),
            accessTokenProvider: FixedResilienceTokenProvider(),
            retryPolicy: RetryPolicy(maxRetries: 0),
            circuitBreaker: CircuitBreaker(failureThreshold: 1, resetTimeout: 60)
        )

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected the first request to fail")
        } catch NetworkError.httpError(statusCode: 503, _) {
        }

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected the circuit breaker to fast-fail")
        } catch NetworkError.circuitBreakerOpen {
        }

        XCTAssertEqual(CircuitURLProtocol.requestCount, 1)
    }

    func testCircuitBreakerOpensAfterThresholdAndFastFails() async {
        let breaker = CircuitBreaker(failureThreshold: 2, resetTimeout: 60)

        let firstRequestAllowed = await breaker.shouldAllowRequest()
        XCTAssertTrue(firstRequestAllowed)
        await breaker.recordFailure()
        let secondRequestAllowed = await breaker.shouldAllowRequest()
        XCTAssertTrue(secondRequestAllowed)
        await breaker.recordFailure()

        let thirdRequestAllowed = await breaker.shouldAllowRequest()
        XCTAssertFalse(thirdRequestAllowed)
    }

    func testCircuitBreakerAllowsProbeAfterResetAndClosesOnSuccess() async {
        let breaker = CircuitBreaker(failureThreshold: 1, resetTimeout: 0)

        await breaker.recordFailure()
        let probeAllowed = await breaker.shouldAllowRequest()
        XCTAssertTrue(probeAllowed)
        let secondProbeAllowed = await breaker.shouldAllowRequest()
        XCTAssertFalse(secondProbeAllowed)

        await breaker.recordSuccess()
        let requestAfterRecoveryAllowed = await breaker.shouldAllowRequest()
        XCTAssertTrue(requestAfterRecoveryAllowed)
    }

    func testCircuitBreakerReleasesProbeAfterNonHTTPFailure() async {
        let breaker = CircuitBreaker(failureThreshold: 1, resetTimeout: 0)
        await breaker.recordFailure()
        let service = NetworkService(
            baseURL: URL(string: "http://example.com")!,
            retryPolicy: RetryPolicy(maxRetries: 0),
            circuitBreaker: breaker
        )

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected the probe to fail before making an HTTP request")
        } catch NetworkError.insecureURL {
        } catch {
            XCTFail("Expected an insecure URL error, got \(error)")
        }

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected the second probe to fail before making an HTTP request")
        } catch NetworkError.insecureURL {
        } catch NetworkError.circuitBreakerOpen {
            XCTFail("The failed half-open probe was not released")
        } catch {
            XCTFail("Expected an insecure URL error, got \(error)")
        }
    }

    func testDecodingFailureDoesNotResetCircuitBreaker() async {
        DecodingCircuitURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DecodingCircuitURLProtocol.self]
        let breaker = CircuitBreaker(failureThreshold: 1, resetTimeout: 60)
        let service = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration),
            accessTokenProvider: FixedResilienceTokenProvider(),
            retryPolicy: RetryPolicy(maxRetries: 0),
            circuitBreaker: breaker
        )

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected the first response to fail decoding")
        } catch NetworkError.decodingError {
        } catch {
            XCTFail("Expected a decoding error, got \(error)")
        }

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected the transient response to fail")
        } catch NetworkError.httpError(statusCode: 503, _) {
        } catch {
            XCTFail("Expected a transient HTTP error, got \(error)")
        }

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected the circuit breaker to fast-fail")
        } catch NetworkError.circuitBreakerOpen {
        } catch {
            XCTFail("Expected the circuit breaker to be open, got \(error)")
        }
    }
}

private struct FixedResilienceTokenProvider: AccessTokenProvider {
    let accessToken: String? = "test-token"
}

private final class RefreshingTokenProvider: AccessTokenProvider {
    private let lock = NSLock()
    private var token = "old-token"
    private var count = 0

    var accessToken: String? {
        lock.withLock { token }
    }

    var refreshCount: Int {
        lock.withLock { count }
    }

    func refreshToken() async throws -> String {
        try await Task.sleep(for: .milliseconds(20))
        return lock.withLock {
            count += 1
            token = "new-token"
            return token
        }
    }
}

private final class FailingRefreshTokenProvider: AccessTokenProvider {
    let accessToken: String? = "old-token"
    private let lock = NSLock()
    private var _didInvalidateSession = false

    var didInvalidateSession: Bool {
        lock.withLock { _didInvalidateSession }
    }

    func refreshToken() async throws -> String {
        throw URLError(.timedOut)
    }

    func invalidateSession() {
        lock.withLock { _didInvalidateSession = true }
    }
}

private struct UnauthorizedRefreshTokenProvider: AccessTokenProvider {
    let accessToken: String? = "old-token"

    func refreshToken() async throws -> String {
        throw NetworkError.httpError(statusCode: 401)
    }

    func invalidateSession() throws {
        throw AuthError.sessionRemovalFailed
    }
}

private struct FailingInvalidationTokenProvider: AccessTokenProvider {
    let accessToken: String? = "old-token"

    func refreshToken() async throws -> String { "new-token" }

    func invalidateSession() throws {
        throw AuthError.sessionRemovalFailed
    }
}

private final class CancellableRefreshTokenProvider: AccessTokenProvider {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, Error>?
    private var cancellationPending = false
    private var _refreshCount = 0
    private var _cancelCount = 0

    let accessToken: String? = "token-1"

    var refreshCount: Int {
        lock.withLock { _refreshCount }
    }

    var cancelCount: Int {
        lock.withLock { _cancelCount }
    }

    func refreshToken() async throws -> String {
        let refreshNumber = lock.withLock {
            _refreshCount += 1
            return _refreshCount
        }
        guard refreshNumber == 1 else { return "token-\(refreshNumber)" }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let shouldCancel = lock.withLock {
                    self.continuation = continuation
                    guard self.cancellationPending else { return false }
                    self.cancellationPending = false
                    return true
                }
                if shouldCancel {
                    continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            self.cancelRefresh()
        }
    }

    nonisolated func cancelRefresh() {
        lock.withLock { _cancelCount += 1 }
    }

    func finishCancellation() {
        let continuation = lock.withLock { () -> CheckedContinuation<String, Error>? in
            guard let continuation = self.continuation else {
                self.cancellationPending = true
                return nil
            }
            self.continuation = nil
            return continuation
        }
        continuation?.resume(throwing: CancellationError())
    }

    func waitForRefreshStart() async -> Bool {
        await waitUntil { self.refreshCount > 0 }
    }

    func waitForCancellation() async -> Bool {
        await waitUntil { self.cancelCount > 0 }
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return false
    }
}

private final class SuccessfulRefreshTokenProvider: AccessTokenProvider {
    private let lock = NSLock()
    private var token = "old-token"
    private var _refreshCount = 0
    private var _didInvalidateSession = false

    var accessToken: String? { lock.withLock { token } }

    var refreshCount: Int {
        lock.withLock { _refreshCount }
    }

    var didInvalidateSession: Bool {
        lock.withLock { _didInvalidateSession }
    }

    func refreshToken() async throws -> String {
        lock.withLock {
            _refreshCount += 1
            token = "new-token"
            return token
        }
    }

    func invalidateSession() {
        lock.withLock { _didInvalidateSession = true }
    }
}

private final class RetryURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var responses: [Int] = []
    private(set) static var requestCount = 0

    static func reset(statusCodes: [Int]) {
        lock.withLock {
            responses = statusCodes
            requestCount = 0
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let statusCode = Self.lock.withLock { () -> Int in
            Self.requestCount += 1
            return Self.responses.isEmpty ? 200 : Self.responses.removeFirst()
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"status\":\"success\",\"data\":{\"spaces\":[],\"pagination\":{\"page\":1,\"limit\":10,\"totalCount\":0,\"totalPages\":0}}}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class AuthURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private(set) static var requestCount = 0
    private(set) static var lastAuthorization: String?

    static func reset() {
        lock.withLock {
            requestCount = 0
            lastAuthorization = nil
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let statusCode = Self.lock.withLock { () -> Int in
            Self.requestCount += 1
            Self.lastAuthorization = request.value(forHTTPHeaderField: "Authorization")
            return Self.lastAuthorization == "Bearer old-token" ? 401 : 200
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"status\":\"success\",\"data\":{\"spaces\":[],\"pagination\":{\"page\":1,\"limit\":10,\"totalCount\":0,\"totalPages\":0}}}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class TransientRefreshURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private(set) static var requestCount = 0

    static func reset() {
        lock.withLock { requestCount = 0 }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.withLock { Self.requestCount += 1 }
        let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class AlwaysUnauthorizedURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class CircuitURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private(set) static var requestCount = 0

    static func reset() {
        lock.withLock { requestCount = 0 }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.withLock { Self.requestCount += 1 }
        let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class DecodingCircuitURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var responses: [(statusCode: Int, data: Data)] = []

    static func reset() {
        lock.withLock {
            responses = [
                (200, Data("invalid".utf8)),
                (503, Data())
            ]
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let response = Self.lock.withLock({ () -> (statusCode: Int, data: Data)? in
            guard !Self.responses.isEmpty else { return nil }
            return Self.responses.removeFirst()
        }) else {
            XCTFail("Unexpected request: no queued response remains")
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
