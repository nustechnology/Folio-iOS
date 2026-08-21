@testable import Folio
import Foundation
import XCTest

final class AuthRepositoryTests: XCTestCase {
    func testSignOutRemovesStoredAuthenticationSession() throws {
        let storage = RecordingStorage()
        let session = AuthTokenDTO(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        try storage.save(session, forKey: StorageKey.authSession)
        let repository = AuthRepository(networkService: UnusedNetworkService(), localStorage: storage)

        try repository.signOut()

        XCTAssertNil(try storage.load(forKey: StorageKey.authSession) as AuthTokenDTO?)
    }

    func testSignOutThrowsWhenStoredAuthenticationSessionCannotBeRemoved() async throws {
        let storage = RecordingStorage()
        storage.removeError = StorageError.unavailable
        let networkService = RecordingNetworkService()
        let repository = AuthRepository(networkService: networkService, localStorage: storage)

        do {
            try await repository.signOutAwaitingCancellation()
            XCTFail("Expected sign-out to fail when session removal fails")
        } catch let error as AuthError {
            XCTAssertEqual(error, .sessionRemovalFailed)
        }

        XCTAssertFalse(networkService.didCancelPendingRefresh)
    }

    func testSignOutDoesNotCancelPendingRefreshWhenRemovalFails() {
        let storage = RecordingStorage()
        storage.removeError = StorageError.unavailable
        let networkService = RecordingNetworkService()
        let repository = AuthRepository(networkService: networkService, localStorage: storage)

        XCTAssertThrowsError(try repository.signOut()) { error in
            XCTAssertEqual(error as? AuthError, .sessionRemovalFailed)
        }

        XCTAssertFalse(networkService.didCancelPendingRefresh)
    }

    func testSignInFailsWhenSessionCannotBePersisted() async {
        let storage = RecordingStorage()
        storage.saveError = StorageError.unavailable
        let repository = AuthRepository(networkService: SuccessfulAuthNetworkService(), localStorage: storage)

        do {
            _ = try await repository.signIn(email: "test@example.com", password: "password")
            XCTFail("Expected session persistence to fail")
        } catch let error as AuthError {
            XCTAssertEqual(error, .sessionPersistenceFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSignUpFailsWhenSessionCannotBePersisted() async {
        let storage = RecordingStorage()
        storage.saveError = StorageError.unavailable
        let repository = AuthRepository(networkService: SuccessfulAuthNetworkService(), localStorage: storage)

        do {
            _ = try await repository.signUp(name: "Test User", email: "test@example.com", password: "password")
            XCTFail("Expected session persistence to fail")
        } catch let error as AuthError {
            XCTAssertEqual(error, .sessionPersistenceFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRefreshTokenFailsAndInvalidatesSessionWhenPersistenceFails() async throws {
        let storage = RecordingStorage()
        let oldSession = AuthTokenDTO(
            accessToken: "old-access-token",
            refreshToken: "old-refresh-token",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        try storage.save(oldSession, forKey: StorageKey.authSession)
        storage.saveError = StorageError.unavailable
        let repository = AuthRepository(networkService: SuccessfulAuthNetworkService(), localStorage: storage)

        do {
            _ = try await repository.refreshToken("old-refresh-token")
            XCTFail("Expected session persistence to fail")
        } catch let error as AuthError {
            XCTAssertEqual(error, .sessionPersistenceFailed)
        }

        XCTAssertNil(try storage.load(forKey: StorageKey.authSession) as AuthTokenDTO?)
    }

    func testRefreshTokenDoesNotReportSessionInvalidatedWhenCleanupFails() async throws {
        let storage = RecordingStorage()
        let oldSession = AuthTokenDTO(
            accessToken: "old-access-token",
            refreshToken: "old-refresh-token",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        try storage.save(oldSession, forKey: StorageKey.authSession)
        storage.saveError = StorageError.unavailable
        storage.removeError = StorageError.unavailable
        let repository = AuthRepository(networkService: SuccessfulAuthNetworkService(), localStorage: storage)

        do {
            _ = try await repository.refreshToken("old-refresh-token")
            XCTFail("Expected session persistence to fail")
        } catch let error as AuthError {
            XCTAssertEqual(error, .sessionPersistenceFailed)
        }

        XCTAssertEqual(try storage.load(forKey: StorageKey.authSession) as AuthTokenDTO?, oldSession)
    }

    func testRequestPasswordResetSucceedsWhenLinkRequestIsAccepted() async {
        let repository = AuthRepository(networkService: SuccessfulAuthNetworkService(), localStorage: RecordingStorage())

        do {
            try await repository.requestPasswordReset(email: "test@example.com")
        } catch {
            XCTFail("Expected password reset to succeed: \(error)")
        }
    }

    func testRequestPasswordResetMapsNetworkError() async {
        let repository = AuthRepository(networkService: UnusedNetworkService(), localStorage: RecordingStorage())

        do {
            try await repository.requestPasswordReset(email: "test@example.com")
            XCTFail("Expected password reset to fail")
        } catch let error as AuthError {
            guard case .networkError = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class RecordingStorage: LocalStorageProtocol {
    private var values: [String: Data] = [:]
    var saveError: Error?
    var removeError: Error?

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        if let saveError { throw saveError }
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

private enum StorageError: Error {
    case unavailable
}

private struct SuccessfulAuthNetworkService: NetworkServiceProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        guard let response = AuthResponseDTO(
            status: "success",
            data: AuthDataDTO(accessToken: "new-access-token", refreshToken: "new-refresh-token")
        ) as? T else {
            throw NetworkError.invalidResponse
        }

        return response
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {}

    func cancelPendingRefresh() {}

    func cancelPendingRefreshAndWait() async {}
}

private struct UnusedNetworkService: NetworkServiceProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        throw NetworkError.invalidResponse
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {
        throw NetworkError.invalidResponse
    }

    func cancelPendingRefresh() {}

    func cancelPendingRefreshAndWait() async {}
}

private final class RecordingNetworkService: NetworkServiceProtocol {
    private(set) var didCancelPendingRefresh = false

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        throw NetworkError.invalidResponse
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {
        throw NetworkError.invalidResponse
    }

    func cancelPendingRefresh() {
        didCancelPendingRefresh = true
    }

    func cancelPendingRefreshAndWait() async {
        didCancelPendingRefresh = true
    }
}
