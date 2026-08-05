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

    func testUpdateSpaceUsesPatchMethod() {
        let endpoint = WorkspaceEndpoint.update(id: "space-id", name: "Research", objective: "Objective")

        XCTAssertEqual(endpoint.method.rawValue, "PATCH")
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
