@testable import Folio
import XCTest

@MainActor
final class NoteRepositoryTests: XCTestCase {
    func testFetchNotesMapsSummariesAndPagination() async throws {
        let service = NoteRepositoryNetworkService()
        let repository = NoteRepository(networkService: service)

        let result = try await repository.fetchNotes(query: NoteListQuery(spaceId: "space-1"))

        XCTAssertEqual(result.notes.map(\.title), ["Saved answer"])
        XCTAssertEqual(result.notes.first?.originType, .savedAssistantAnswer)
        XCTAssertEqual(result.pagination?.totalPages, 2)
    }

    func testFetchNoteMapsFullDetail() async throws {
        let service = NoteRepositoryNetworkService()
        let repository = NoteRepository(networkService: service)

        let note = try await repository.fetchNote(spaceId: "space-1", noteId: "note-1")

        XCTAssertEqual(note.title, "Full Note")
        XCTAssertEqual(note.content, "Full content")
        XCTAssertEqual(note.originType, .userCreated)
    }

    func testCreateNoteSendsRequestAndReturnsCreatedNote() async throws {
        let service = NoteRepositoryNetworkService()
        let repository = NoteRepository(networkService: service)

        let created = try await repository.createNote(
            spaceId: "space-1", title: "Created", content: "Body")

        XCTAssertEqual(created.title, "Created")
        XCTAssertEqual(created.content, "Body")
        XCTAssertEqual(created.originType, .userCreated)
    }

    func testCreateNoteUseCaseDelegatesToRepositoryContract() async throws {
        let repository = CreateOnlyNoteRepository()
        let useCase = CreateNoteUseCase(repository: repository)

        let note = try await useCase.execute(spaceId: "space-1", title: "Created", content: "Body")

        XCTAssertEqual(note.title, "Created")
        XCTAssertEqual(repository.receivedSpaceId, "space-1")
        XCTAssertEqual(repository.receivedContent, "Body")
    }

    func testConvertNoteToSourceMapsReturnedSource() async throws {
        let service = NoteRepositoryNetworkService()
        let repository = NoteRepository(networkService: service)

        let source = try await repository.convertNoteToSource(
            spaceId: "space-1", noteId: "note-1", title: "Snapshot")

        XCTAssertEqual(source.id, "source-1")
        XCTAssertEqual(source.title, "Snapshot")
        XCTAssertEqual(source.processingState, .added)
    }

    func testConvertNoteToSourceUseCaseDelegatesToRepositoryContract() async throws {
        let repository = CreateOnlyNoteRepository()
        let useCase = ConvertNoteToSourceUseCase(repository: repository)

        let source = try await useCase.execute(
            spaceId: "space-1", noteId: "note-1", title: "Snapshot")

        XCTAssertEqual(source.id, "source-1")
        XCTAssertEqual(repository.receivedNoteId, "note-1")
        XCTAssertEqual(repository.receivedSourceTitle, "Snapshot")
    }

    func testUpdateNoteSendsRequestAndReturnsUpdatedNote() async throws {
        let service = NoteRepositoryNetworkService()
        let repository = NoteRepository(networkService: service)

        let updated = try await repository.updateNote(
            spaceId: "space-1", noteId: "note-1", title: "Updated", content: "<p><em>New</em></p>")

        XCTAssertEqual(updated.title, "Full Note")
        XCTAssertEqual(service.lastRequestPayload?["content"] as? String, "<p><em>New</em></p>")
    }

    func testCreateNoteSendsHTMLWithoutOriginMetadata() async throws {
        let service = NoteRepositoryNetworkService()
        let repository = NoteRepository(networkService: service)

        _ = try await repository.createNote(spaceId: "space-1", title: "Created", content: "<p>Body</p>")

        XCTAssertEqual(service.lastRequestPayload?["content"] as? String, "<p>Body</p>")
        XCTAssertNil(service.lastRequestPayload?["origin"])
    }

    func testDeleteNoteCallsRequestVoid() async throws {
        let service = NoteRepositoryNetworkService()
        let repository = NoteRepository(networkService: service)

        try await repository.deleteNote(spaceId: "space-1", noteId: "note-1")
    }
}

private enum StubNetworkError: Error {
    case responseTypeMismatch
}

private final class NoteRepositoryNetworkService: NetworkServiceProtocol {
    private(set) var lastRequestPayload: [String: Any]?

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        if let body = endpoint.body {
            lastRequestPayload = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        }
        switch endpoint.method {
        case .get where endpoint.path.contains("/notes/note-1"):
            let response = NoteResponseDTO(
                status: "success",
                data: NoteDataDTO(
                    note: NoteDTO(
                        id: "note-1", researchSpaceId: "space-1", title: "Full Note",
                        originType: "UserCreated", content: "Full content",
                        createdAt: .now, updatedAt: .now, citationCount: nil
                    )
                )
            )
            guard let typed = response as? T else { throw StubNetworkError.responseTypeMismatch }
            return typed
        case .patch:
            let response = NoteResponseDTO(
                status: "success",
                data: NoteDataDTO(
                    note: NoteDTO(
                        id: "note-1", researchSpaceId: "space-1", title: "Full Note",
                        originType: "UserCreated", content: "Full content",
                        createdAt: .now, updatedAt: .now, citationCount: nil
                    )
                )
            )
            guard let typed = response as? T else { throw StubNetworkError.responseTypeMismatch }
            return typed
        case .post:
            if endpoint.path.contains("convert-to-source") {
                let response = SourceResponseDTO(
                    status: "success",
                    data: SourceDataDTO(
                        source: SourceDTO(
                            id: "source-1", researchSpaceId: "space-1", sourceType: "Manual",
                            title: "Snapshot", author: "", sourceUrl: nil, fileName: nil,
                            fileSize: nil, fileType: nil, pageCount: nil, characterCount: nil,
                            content: nil, structuredContent: nil, processingState: "added",
                            processingError: nil, createdAt: .now, updatedAt: .now
                        )
                    )
                )
                guard let typed = response as? T else { throw StubNetworkError.responseTypeMismatch }
                return typed
            }
            let response = NoteResponseDTO(
                status: "success",
                data: NoteDataDTO(
                    note: NoteDTO(
                        id: "note-created", researchSpaceId: "space-1", title: "Created",
                        originType: "UserCreated", content: "Body",
                        createdAt: .now, updatedAt: .now, citationCount: nil
                    )
                )
            )
            guard let typed = response as? T else { throw StubNetworkError.responseTypeMismatch }
            return typed
        default:
            let response = NoteListResponseDTO(
                status: "success",
                data: NoteListDataDTO(
                    notes: [
                        NoteSummaryDTO(
                            id: "note-1",
                            researchSpaceId: "space-1",
                            title: "Saved answer",
                            originType: "SavedAssistantAnswer",
                            contentPreview: "Preview",
                            createdAt: .now,
                            updatedAt: .now,
                            citationCount: 2
                        )
                    ],
                    pagination: NotePaginationDTO(page: 1, limit: 10, totalCount: 11, totalPages: 2)
                )
            )
            guard let typed = response as? T else { throw StubNetworkError.responseTypeMismatch }
            return typed
        }
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {}
}

private final class CreateOnlyNoteRepository: NoteRepositoryProtocol {
    private(set) var receivedSpaceId: String?
    private(set) var receivedContent: String?
    private(set) var receivedNoteId: String?
    private(set) var receivedSourceTitle: String?

    func createNote(spaceId: String, title: String, content: String) async throws -> Note {
        receivedSpaceId = spaceId
        receivedContent = content
        return Note(
            id: "note-created", researchSpaceId: spaceId, title: title,
            originType: .userCreated, content: content,
            createdAt: .now, updatedAt: .now, citationCount: nil)
    }

    func fetchNotes(query: NoteListQuery) async throws -> NoteListResult { fatalError("Unused") }
    func fetchNote(spaceId: String, noteId: String) async throws -> Note { fatalError("Unused") }
    func updateNote(spaceId: String, noteId: String, title: String, content: String) async throws -> Note { fatalError("Unused") }
    func deleteNote(spaceId: String, noteId: String) async throws { fatalError("Unused") }
    func convertNoteToSource(spaceId: String, noteId: String, title: String) async throws -> Source {
        receivedSpaceId = spaceId
        receivedNoteId = noteId
        receivedSourceTitle = title
        return Source(
            id: "source-1", researchSpaceId: spaceId, sourceType: .manual, title: title,
            author: "", sourceUrl: "", fileName: "", fileSize: 0, fileType: "", pageCount: 0,
            characterCount: 0, content: "", structuredContent: nil, processingState: .added,
            processingError: "", createdAt: .now, updatedAt: .now
        )
    }
}
