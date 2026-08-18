@testable import Folio
import Foundation
import XCTest

final class AccessTokenProviderTests: XCTestCase {
    func testRefreshTokenPreservesUnauthorizedResponseWhenSessionRemovalFails() async throws {
        let storage = AccessTokenProviderTestStorage()
        try storage.save(
            AuthTokenDTO(
                accessToken: "access-token",
                refreshToken: "refresh-token",
                expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
            ),
            forKey: StorageKey.authSession
        )
        storage.removeError = AccessTokenProviderTestStorageError.unavailable
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UnauthorizedResponseURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let provider = SessionAccessTokenProvider(
            localStorage: storage,
            baseURL: URL(string: "https://example.com")!,
            session: session
        )

        do {
            _ = try await provider.refreshToken()
            XCTFail("Expected unauthorized response")
        } catch NetworkError.httpError(statusCode: 401, _) {
        } catch {
            XCTFail("Expected an unauthorized response, got \(error)")
        }
    }

    func testInvalidateSessionReportsSessionRemovalFailure() {
        let storage = AccessTokenProviderTestStorage()
        storage.removeError = AccessTokenProviderTestStorageError.unavailable
        let provider = SessionAccessTokenProvider(
            localStorage: storage,
            baseURL: URL(string: "https://example.com")!
        )

        XCTAssertThrowsError(try provider.invalidateSession()) { error in
            XCTAssertEqual(error as? AuthError, .sessionRemovalFailed)
        }
    }
}

private final class AccessTokenProviderTestStorage: LocalStorageProtocol {
    var removeError: Error?
    private var values: [String: Data] = [:]

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        values[key] = try JSONEncoder().encode(value)
    }

    func load<T: Codable>(forKey key: String) throws -> T? {
        guard let data = values[key] else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func remove(forKey key: String) throws {
        if let removeError { throw removeError }
        values.removeValue(forKey: key)
    }

}

private enum AccessTokenProviderTestStorageError: Error {
    case unavailable
}

private final class UnauthorizedResponseURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
