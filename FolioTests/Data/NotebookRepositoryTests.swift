@testable import Folio
import XCTest

final class NotebookRepositoryTests: XCTestCase {
    func testFailedSaveKeepsLocalEditAndFetchReplaysItWhenServerUnchanged() async throws {
        let storage = InMemoryLocalStorage()
        let network = NotebookRepositoryNetworkService()
        let repository = NotebookRepository(localStorage: storage, networkService: network)

        let serverDate = Date(timeIntervalSince1970: 1_000_000)
        network.serverUpdatedAt = serverDate
        network.saveShouldFail = true

        // Seed the cache so the draft records which server version it is based on.
        _ = try await repository.fetchNotebook(spaceId: "space-1")

        let localEntry = NotebookEntry(
            id: "notebook-1", researchSpaceId: "space-1",
            content: "<p>local unsynced edit</p>",
            createdAt: serverDate, updatedAt: Date()
        )

        do {
            try await repository.saveNotebook(entry: localEntry)
            XCTFail("Expected failed save to throw")
        } catch {
            // PUT failed; the local edit must remain cached as unsynced.
        }

        // Server is unchanged relative to the draft's baseline → replay the local edit.
        let fetched = try await repository.fetchNotebook(spaceId: "space-1")
        XCTAssertEqual(fetched.entry.content, "<p>local unsynced edit</p>")
        XCTAssertFalse(fetched.preservedOfflineDraft)
        // One PUT from saveNotebook plus one replay attempt.
        XCTAssertEqual(network.saveCount, 2)
    }

    func testSuccessfulSaveMarksEntrySyncedSoServerCopyOverwritesCache() async throws {
        let storage = InMemoryLocalStorage()
        let network = NotebookRepositoryNetworkService()
        let repository = NotebookRepository(localStorage: storage, networkService: network)

        network.saveShouldFail = false
        let entry = NotebookEntry(
            id: "notebook-1", researchSpaceId: "space-1",
            content: "<p>saved</p>",
            createdAt: Date(timeIntervalSince1970: 1_000_000), updatedAt: .now
        )

        try await repository.saveNotebook(entry: entry)

        let fetched = try await repository.fetchNotebook(spaceId: "space-1")
        XCTAssertEqual(fetched.entry.content, "<p>server copy</p>")
        XCTAssertEqual(network.saveCount, 1)
    }

    func testFetchPreservesOfflineEditAndFlagsConflictOnRealRemoteChange() async throws {
        let storage = InMemoryLocalStorage()
        let network = NotebookRepositoryNetworkService()
        let repository = NotebookRepository(localStorage: storage, networkService: network)

        let oldServerDate = Date(timeIntervalSince1970: 1_000_000)
        network.serverUpdatedAt = oldServerDate
        network.saveShouldFail = true

        // Seed cache with an old server baseline.
        _ = try await repository.fetchNotebook(spaceId: "space-1")

        let localEntry = NotebookEntry(
            id: "notebook-1", researchSpaceId: "space-1",
            content: "<p>unsynced offline edit</p>",
            createdAt: oldServerDate, updatedAt: oldServerDate
        )

        do {
            try await repository.saveNotebook(entry: localEntry)
            XCTFail("Expected failed save to throw")
        } catch {
            // PUT failed; local edit stays cached as unsynced.
        }

        // Server genuinely changed after the draft was based on it.
        network.serverUpdatedAt = Date(timeIntervalSince1970: 2_000_000)
        let fetched = try await repository.fetchNotebook(spaceId: "space-1")
        XCTAssertEqual(fetched.entry.content, "<p>server copy</p>")
        XCTAssertTrue(fetched.preservedOfflineDraft)

        // The unsynced edit is preserved under the recovery key, not discarded.
        let recovered: NotebookDTO? = try storage.load(forKey: "notebook_space-1_recovery")
        XCTAssertEqual(recovered?.content, "<p>unsynced offline edit</p>")
    }

    func testNotebookDTODecodesWithoutNeedsSyncKeyAsInSync() throws {
        let jsonString = """
        {
          "id": "n",
          "researchSpaceId": "s",
          "content": "body",
          "createdAt": \(Date().timeIntervalSinceReferenceDate),
          "updatedAt": \(Date().timeIntervalSinceReferenceDate)
        }
        """

        let dto = try JSONDecoder().decode(NotebookDTO.self, from: Data(jsonString.utf8))
        XCTAssertFalse(dto.needsSync)
    }

    func testNotebookDTODecodesNullFieldsForEmptyNotebook() throws {
        // The server returns null id/createdAt/updatedAt when no notebook exists yet.
        let jsonString = """
        {
          "id": null,
          "researchSpaceId": "s",
          "content": "",
          "updatedAt": null,
          "createdAt": null
        }
        """

        let dto = try JSONDecoder().decode(NotebookDTO.self, from: Data(jsonString.utf8))
        XCTAssertEqual(dto.id, "")
        XCTAssertEqual(dto.content, "")
        XCTAssertFalse(dto.needsSync)
        XCTAssertNotNil(dto.updatedAt)
        XCTAssertNotNil(dto.createdAt)
    }
}

private final class NotebookRepositoryNetworkService: NetworkServiceProtocol {
    var serverUpdatedAt: Date = .now
    var saveShouldFail = false
    private(set) var saveCount = 0

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        switch endpoint.method {
        case .get:
            let response = NotebookResponseDTO(
                status: "success",
                data: NotebookDataDTO(
                    notebook: NotebookDTO(
                        id: "notebook-1", researchSpaceId: "space-1",
                        content: "<p>server copy</p>",
                        createdAt: serverUpdatedAt, updatedAt: serverUpdatedAt
                    )
                )
            )
            guard let typed = response as? T else { throw StubError.responseTypeMismatch }
            return typed
        case .put:
            saveCount += 1
            if saveShouldFail {
                throw URLError(.notConnectedToInternet)
            }
            let response = NotebookResponseDTO(
                status: "success",
                data: NotebookDataDTO(
                    notebook: NotebookDTO(
                        id: "notebook-1", researchSpaceId: "space-1", content: "",
                        createdAt: .now, updatedAt: .now
                    )
                )
            )
            guard let typed = response as? T else { throw StubError.responseTypeMismatch }
            return typed
        default:
            throw StubError.unexpectedMethod
        }
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {}
}

private enum StubError: Error {
    case responseTypeMismatch
    case unexpectedMethod
}

private final class InMemoryLocalStorage: LocalStorageProtocol {
    private var store: [String: Data] = [:]

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        store[key] = try JSONEncoder().encode(value)
    }

    func load<T: Codable>(forKey key: String) throws -> T? {
        guard let data = store[key] else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func remove(forKey key: String) { store.removeValue(forKey: key) }

    func clear() { store.removeAll() }
}
