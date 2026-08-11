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
}
