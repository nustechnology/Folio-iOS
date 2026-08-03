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

        let _: [WorkspaceDTO] = try await service.request(WorkspaceEndpoint.list)

        XCTAssertEqual(URLProtocolStub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
    }

    func testUnauthenticatedRequestDoesNotAddBearerToken() async throws {
        let service = makeNetworkService(accessToken: "token-123")

        try await service.requestVoid(AuthEndpoint.signIn(email: "test@example.com", password: "password"))

        XCTAssertNil(URLProtocolStub.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    private func makeNetworkService(accessToken: String?) -> NetworkService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return NetworkService(
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration),
            accessTokenProvider: FixedAccessTokenProvider(accessToken: accessToken)
        )
    }
}

private struct FixedAccessTokenProvider: AccessTokenProvider {
    let accessToken: String?
}
