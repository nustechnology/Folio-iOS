@testable import Folio
import XCTest

final class NoteEndpointTests: XCTestCase {
    func testListEndpointUsesSpaceScopedRecentlyUpdatedRequest() {
        let endpoint = NoteListEndpoint(query: NoteListQuery(spaceId: "space-1", search: "scaling", page: 2, limit: 10))

        XCTAssertEqual(endpoint.path, "/api/v1/spaces/space-1/notes")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.queryItems, [
            URLQueryItem(name: "search", value: "scaling"),
            URLQueryItem(name: "sort", value: "recently-updated"),
            URLQueryItem(name: "origin", value: "all"),
            URLQueryItem(name: "page", value: "2"),
            URLQueryItem(name: "limit", value: "10")
        ])
    }

    func testDetailEndpointUsesCorrectPathAndMethod() {
        let endpoint = NoteDetailEndpoint(spaceId: "space-1", noteId: "note-42")

        XCTAssertEqual(endpoint.path, "/api/v1/spaces/space-1/notes/note-42")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertTrue(endpoint.requiresAuthentication)
    }

    func testUpdateEndpointUsesPatchWithJSONBody() throws {
        let endpoint = UpdateNoteEndpoint(spaceId: "space-1", noteId: "note-42", title: "New", content: "Body")

        XCTAssertEqual(endpoint.path, "/api/v1/spaces/space-1/notes/note-42")
        XCTAssertEqual(endpoint.method, .patch)
        XCTAssertTrue(endpoint.requiresAuthentication)

        let body = try XCTUnwrap(endpoint.body)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        XCTAssertEqual(payload["title"], "New")
        XCTAssertEqual(payload["content"], "Body")
    }

    func testDeleteEndpointUsesCorrectPathAndMethod() {
        let endpoint = DeleteNoteEndpoint(spaceId: "space-1", noteId: "note-42")

        XCTAssertEqual(endpoint.path, "/api/v1/spaces/space-1/notes/note-42")
        XCTAssertEqual(endpoint.method, .delete)
        XCTAssertTrue(endpoint.requiresAuthentication)
    }

    func testCreateEndpointUsesSpaceScopedPostWithJSONBody() throws {
        let endpoint = CreateNoteEndpoint(spaceId: "space-1", title: "New", content: "Body")

        XCTAssertEqual(endpoint.path, "/api/v1/spaces/space-1/notes")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertTrue(endpoint.requiresAuthentication)

        let body = try XCTUnwrap(endpoint.body)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        XCTAssertEqual(payload["title"], "New")
        XCTAssertEqual(payload["content"], "Body")
        XCTAssertNil(payload["originType"])
    }

    func testConvertToSourceEndpointUsesNoteScopedPostWithTitleBody() throws {
        let endpoint = ConvertNoteToSourceEndpoint(
            spaceId: "space-1", noteId: "note-42", title: "Snapshot title")

        XCTAssertEqual(endpoint.path, "/api/v1/spaces/space-1/notes/note-42/convert-to-source")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertTrue(endpoint.requiresAuthentication)

        let body = try XCTUnwrap(endpoint.body)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        XCTAssertEqual(payload, ["title": "Snapshot title"])
    }

    func testCreateEndpointUsesNoteResponseEnvelope() throws {
        let endpoint = CreateNoteEndpoint(spaceId: "space-1", title: "New", content: "Body")
        let response = try JSONDecoder.noteTestDecoder.decode(
            NoteResponseDTO.self,
            from: Data(
                """
                {"status":"success","data":{"note":{"id":"note-1","researchSpaceId":"space-1","title":"New","originType":"UserCreated","content":"Body","createdAt":"2026-08-14T10:00:00Z","updatedAt":"2026-08-14T10:00:00Z","citationCount":0}}}
                """.utf8
            )
        )

        XCTAssertEqual(response.data.note.toDomain().originType, .userCreated)
        XCTAssertEqual(endpoint.path, "/api/v1/spaces/space-1/notes")
    }
}

private extension JSONDecoder {
    static var noteTestDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
