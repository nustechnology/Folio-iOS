import Foundation
import XCTest
@testable import Folio

final class NetworkServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
    }

    func testAuthenticatedRequestAddsBearerToken() async throws {
        let service = makeNetworkService(accessToken: "token-123")

        let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))

        XCTAssertEqual(URLProtocolStub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
    }

    func testUnauthenticatedRequestDoesNotAddBearerToken() async throws {
        let service = makeNetworkService(accessToken: "token-123")

        try await service.requestVoid(AuthEndpoint.signIn(email: "test@example.com", password: "password"))

        XCTAssertNil(URLProtocolStub.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    func testSpaceListRequestOmitsUnsupportedPaginationQueryItems() async throws {
        let service = makeNetworkService(accessToken: nil)

        let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))

        XCTAssertEqual(URLProtocolStub.lastRequest?.url?.path, "/api/v1/spaces")
        XCTAssertEqual(URLProtocolStub.lastRequest?.url?.query, "sort=recently-updated")
    }

    func testSpaceListRequestEncodesPaginationWhenExplicitlySupplied() async throws {
        let service = makeNetworkService(accessToken: nil)
        let query = WorkspaceListQuery(sort: "recently-updated", page: 3, limit: 25)

        let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: query))

        XCTAssertEqual(URLProtocolStub.lastRequest?.url?.path, "/api/v1/spaces")
        XCTAssertEqual(URLProtocolStub.lastRequest?.url?.query, "sort=recently-updated&page=3&limit=25")
    }

    func testReadEndpointUsesExplicitResiliencePolicy() {
        let policy = WorkspaceEndpoint.list(query: .initial).resiliencePolicy

        XCTAssertEqual(policy.requestTimeout, 15)
        XCTAssertEqual(policy.resourceTimeout, 120)
        XCTAssertEqual(policy.maximumAttempts, 3)
        XCTAssertTrue(policy.isRetryable)
    }

    func testTransientServerFailureRetriesAndThenSucceeds() async throws {
        URLProtocolStub.responses = [
            URLProtocolStub.StubResponse(statusCode: 503, data: Data("{}".utf8)),
            URLProtocolStub.StubResponse(
                statusCode: 200,
                data: Data("{\"status\":\"success\",\"data\":{\"spaces\":[],\"pagination\":null}}".utf8)
            )
        ]
        let service = makeNetworkService(accessToken: nil)

        let result: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))

        XCTAssertEqual(result.data.spaces.count, 0)
        XCTAssertEqual(URLProtocolStub.responses.count, 0)
    }

    func testNonRetryableClientFailureDoesNotRetry() async throws {
        URLProtocolStub.responses = [
            URLProtocolStub.StubResponse(statusCode: 400, data: Data("{}".utf8)),
            URLProtocolStub.StubResponse(statusCode: 200, data: Data("{}".utf8))
        ]
        let service = makeNetworkService(accessToken: nil)

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected request to fail")
        } catch let error as NetworkError {
            guard case .httpError(let statusCode, _) = error else {
                return XCTFail("Expected HTTP error, got \(error)")
            }
            XCTAssertEqual(statusCode, 400)
        }

        XCTAssertEqual(URLProtocolStub.responses.count, 1)
    }

    func testOfflineTransportFailureIsClassified() async throws {
        URLProtocolStub.errors = [
            URLError(.notConnectedToInternet),
            URLError(.notConnectedToInternet),
            URLError(.notConnectedToInternet)
        ]
        let service = makeNetworkService(accessToken: nil)

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected request to fail")
        } catch let error as NetworkError {
            guard case .offline = error else {
                return XCTFail("Expected offline error, got \(error)")
            }
        }
    }

    func testCancellationDuringRetryBackoffIsPreserved() async throws {
        URLProtocolStub.responses = [
            URLProtocolStub.StubResponse(statusCode: 503, data: Data("{}".utf8))
        ]
        let service = makeNetworkService(
            accessToken: nil,
            sleep: { _ in throw CancellationError() }
        )

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Cancellation must propagate to the caller so presentation can suppress it.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testCancellationDuringActiveRequestIsPreserved() async throws {
        URLProtocolStub.errors = [URLError(.cancelled)]
        let service = makeNetworkService(accessToken: nil)

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Cancellation must propagate to the caller so presentation can suppress it.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testRetryAfterHeaderControlsRetryDelay() async throws {
        URLProtocolStub.responses = [
            URLProtocolStub.StubResponse(
                statusCode: 503,
                data: Data("{}".utf8),
                headers: ["Content-Type": "application/json", "Retry-After": "1"]
            ),
            URLProtocolStub.StubResponse(
                statusCode: 200,
                data: Data("{\"status\":\"success\",\"data\":{\"spaces\":[],\"pagination\":null}}".utf8)
            )
        ]
        let recorder = SleepRecorder()
        let service = makeNetworkService(accessToken: nil, sleep: { nanoseconds in
            recorder.record(nanoseconds)
        })

        let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))

        XCTAssertEqual(recorder.values, [1_000_000_000])
    }

    func testAuthenticated401RefreshesTokenAndRetriesOnce() async throws {
        URLProtocolStub.responses = [
            URLProtocolStub.StubResponse(statusCode: 401, data: Data("{}".utf8)),
            URLProtocolStub.StubResponse(
                statusCode: 200,
                data: Data("{\"status\":\"success\",\"data\":{\"spaces\":[],\"pagination\":null}}".utf8)
            )
        ]
        let provider = MutableAccessTokenProvider(accessToken: "old-token", refreshToken: "refresh-token")
        let refreshes = LockedCounter()
        let service = makeNetworkService(
            accessToken: nil,
            accessTokenProvider: provider,
            refreshSession: { refreshToken in
                XCTAssertEqual(refreshToken, "refresh-token")
                refreshes.increment()
                provider.accessToken = "new-token"
            }
        )

        let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))

        XCTAssertEqual(refreshes.value, 1)
        XCTAssertEqual(URLProtocolStub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer new-token")
    }

    func testSecond401AfterRefreshDoesNotRetryAgain() async throws {
        URLProtocolStub.responses = [
            URLProtocolStub.StubResponse(statusCode: 401, data: Data("{}".utf8)),
            URLProtocolStub.StubResponse(statusCode: 401, data: Data("{}".utf8))
        ]
        let provider = MutableAccessTokenProvider(accessToken: "old-token", refreshToken: "refresh-token")
        let refreshes = LockedCounter()
        let service = makeNetworkService(
            accessToken: nil,
            accessTokenProvider: provider,
            refreshSession: { _ in refreshes.increment() }
        )

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected authentication failure")
        } catch let error as NetworkError {
            guard case .unauthorized = error else {
                return XCTFail("Expected unauthorized error, got \(error)")
            }
        }

        XCTAssertEqual(refreshes.value, 1)
        XCTAssertEqual(URLProtocolStub.responses.count, 0)
    }

    func testSecond401AfterRefreshNotifiesSessionInvalidation() async throws {
        URLProtocolStub.responses = [
            URLProtocolStub.StubResponse(statusCode: 401, data: Data("{}".utf8)),
            URLProtocolStub.StubResponse(statusCode: 401, data: Data("{}".utf8))
        ]
        let provider = MutableAccessTokenProvider(accessToken: "old-token", refreshToken: "refresh-token")
        let invalidations = LockedCounter()
        let service = makeNetworkService(
            accessToken: nil,
            accessTokenProvider: provider,
            refreshSession: { _ in },
            onSessionInvalidated: { invalidations.increment() }
        )

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected authentication failure")
        } catch let error as NetworkError {
            guard case .unauthorized = error else {
                return XCTFail("Expected unauthorized error, got \(error)")
            }
        }

        XCTAssertEqual(invalidations.value, 1)
    }

    func testTransientRefreshFailurePreservesSession() async throws {
        URLProtocolStub.responses = [
            URLProtocolStub.StubResponse(statusCode: 401, data: Data("{}".utf8))
        ]
        let provider = MutableAccessTokenProvider(accessToken: "old-token", refreshToken: "refresh-token")
        let invalidations = LockedCounter()
        let service = makeNetworkService(
            accessToken: nil,
            accessTokenProvider: provider,
            refreshSession: { _ in throw AuthError.networkError("offline") },
            onSessionInvalidated: { invalidations.increment() }
        )

        do {
            let _: WorkspaceResponseDTO = try await service.request(WorkspaceEndpoint.list(query: .initial))
            XCTFail("Expected refresh failure")
        } catch {
            if case NetworkError.unauthorized = error {
                XCTFail("Transient refresh failure must not become unauthorized")
            }
        }

        XCTAssertEqual(provider.accessToken, "old-token")
        XCTAssertEqual(invalidations.value, 0)
    }

    private func makeNetworkService(
        accessToken: String?,
        accessTokenProvider: AccessTokenProvider? = nil,
        refreshSession: (@Sendable (String) async throws -> Void)? = nil,
        onSessionInvalidated: (@Sendable () -> Void)? = nil,
        sleep: @escaping @Sendable (UInt64) async throws -> Void = { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) -> NetworkService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return NetworkService(
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration),
            accessTokenProvider: accessTokenProvider ?? FixedAccessTokenProvider(accessToken: accessToken),
            refreshSession: refreshSession,
            onSessionInvalidated: onSessionInvalidated,
            sleep: sleep,
            random: { _ in 0 }
        )
    }
}

private struct FixedAccessTokenProvider: AccessTokenProvider {
    let accessToken: String?
}

private final class MutableAccessTokenProvider: AccessTokenProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var storedAccessToken: String?
    let refreshToken: String?

    init(accessToken: String?, refreshToken: String?) {
        self.storedAccessToken = accessToken
        self.refreshToken = refreshToken
    }

    var accessToken: String? {
        get { lock.withLock { storedAccessToken } }
        set { lock.withLock { storedAccessToken = newValue } }
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int { lock.withLock { count } }

    func increment() {
        lock.withLock { count += 1 }
    }
}

private final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var values: [UInt64] = []

    func record(_ value: UInt64) {
        lock.withLock { values.append(value) }
    }
}
