@testable import Folio
import Foundation

func makeNote(citationCount: Int?) -> Note {
    Note(
        id: "note-1",
        researchSpaceId: "space-1",
        title: "Note",
        originType: .userCreated,
        content: "Content",
        createdAt: .now,
        updatedAt: .now,
        citationCount: citationCount
    )
}

@MainActor
final class FixtureNotesUseCase: FetchNotesUseCaseProtocol {
    private(set) var requestCount = 0

    func execute(query: NoteListQuery) async throws -> NoteListResult {
        requestCount += 1
        let notes = [
            NoteSummary(
                id: "created",
                researchSpaceId: "space-1",
                title: "Created",
                originType: .userCreated,
                contentPreview: "",
                createdAt: .now,
                updatedAt: .now,
                citationCount: nil
            ),
            NoteSummary(
                id: "saved",
                researchSpaceId: "space-1",
                title: "Saved",
                originType: .savedAssistantAnswer,
                contentPreview: "",
                createdAt: .now,
                updatedAt: .now,
                citationCount: nil
            )
        ]
        let filteredNotes = query.origin == "all" ? notes : notes.filter { $0.originType.rawValue == query.origin }
        return NoteListResult(notes: filteredNotes, pagination: nil)
    }

    func waitUntilRequestCount(reaches expectedCount: Int) async {
        while requestCount < expectedCount {
            await Task.yield()
        }
    }
}

struct UnusedFixtureNoteUseCase: FetchNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String) async throws -> Note {
        fatalError("Unused")
    }
}

struct UnusedFixtureUpdateUseCase: UpdateNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String, title: String, content: String) async throws -> Note {
        fatalError("Unused")
    }
}

struct UnusedFixtureDeleteUseCase: DeleteNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String) async throws {}
}

@MainActor
final class FixtureCreateNoteUseCase: CreateNoteUseCaseProtocol {
    private(set) var title: String?
    private(set) var content: String?
    private(set) var wasCalled = false

    func execute(spaceId: String, title: String, content: String) async throws -> Note {
        self.title = title
        self.content = content
        wasCalled = true
        return Note(
            id: "created-note",
            researchSpaceId: spaceId,
            title: title,
            originType: .userCreated,
            content: content,
            createdAt: .now,
            updatedAt: .now,
            citationCount: nil
        )
    }

    func waitUntilCalled() async {
        while !wasCalled {
            await Task.yield()
        }
    }
}
