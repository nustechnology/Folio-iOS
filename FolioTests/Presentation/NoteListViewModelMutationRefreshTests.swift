@testable import Folio
import XCTest

@MainActor
final class NoteListViewModelMutationRefreshTests: XCTestCase {
    func testSavingNoteReloadsTheActiveSortedQuery() async {
        let note = makeNote()
        let fetchNotes = MutationRefreshNotesUseCase(results: [
            NoteListResult(notes: [note.summary], pagination: nil),
            NoteListResult(notes: [makeSummary(id: "alphabetical-result", title: "Apple")], pagination: nil)
        ])
        let viewModel = makeViewModel(fetchNotes: fetchNotes, updateNote: ReturningUpdateNoteUseCase())

        viewModel.handle(.sortSelected(.alphabeticalAZ))
        await waitForTasks()
        viewModel.handle(.editStarted(note))
        viewModel.handle(.editTitleChanged("Zulu"))
        viewModel.handle(.editSaved(note))
        await waitForTasks()

        XCTAssertEqual(viewModel.state.notes.map(\.id), ["alphabetical-result"])
        XCTAssertEqual(fetchNotes.queries.map(\.sort), ["alphabetical-az", "alphabetical-az"])
    }

    func testDeletingNoteReloadsFirstPageToReconcilePagination() async {
        let deletedNote = makeSummary(id: "note-1", title: "Deleted note")
        let fetchNotes = MutationRefreshNotesUseCase(results: [
            NoteListResult(
                notes: [deletedNote],
                pagination: NotePagination(page: 1, limit: 10, totalCount: 2, totalPages: 2)
            ),
            NoteListResult(
                notes: [makeSummary(id: "shifted-note", title: "Shifted note")],
                pagination: NotePagination(page: 1, limit: 10, totalCount: 1, totalPages: 1)
            )
        ])
        let viewModel = makeViewModel(fetchNotes: fetchNotes)

        viewModel.handle(.onAppear)
        await waitForTasks()
        viewModel.handle(.deleteRequested(deletedNote))
        viewModel.handle(.deleteConfirmed)
        await waitForTasks()

        XCTAssertEqual(viewModel.state.notes.map(\.id), ["shifted-note"])
        XCTAssertEqual(fetchNotes.queries.map(\.page), [nil, nil])
        XCTAssertEqual(viewModel.state.pagination?.totalPages, 1)
    }

    private func makeViewModel(
        fetchNotes: any FetchNotesUseCaseProtocol,
        updateNote: any UpdateNoteUseCaseProtocol = UnusedUpdateNoteUseCase()
    ) -> NoteListViewModel {
        NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: fetchNotes,
            fetchNoteUseCase: UnusedFetchNoteUseCase(),
            updateNoteUseCase: updateNote,
            deleteNoteUseCase: ImmediateDeleteNoteUseCase()
        )
    }

    private func makeNote() -> Note {
        Note(
            id: "note-1", researchSpaceId: "space-1", title: "Note",
            originType: .userCreated, content: "Content", createdAt: .now,
            updatedAt: .now, citationCount: nil
        )
    }

    private func makeSummary(id: String, title: String) -> NoteSummary {
        NoteSummary(
            id: id, researchSpaceId: "space-1", title: title,
            originType: .userCreated, contentPreview: "", createdAt: .now,
            updatedAt: .now, citationCount: nil
        )
    }

    private func waitForTasks() async {
        for _ in 0..<4 {
            await Task.yield()
        }
    }
}

@MainActor
private final class MutationRefreshNotesUseCase: FetchNotesUseCaseProtocol {
    private var results: [NoteListResult]
    private(set) var queries: [NoteListQuery] = []

    init(results: [NoteListResult]) {
        self.results = results
    }

    func execute(query: NoteListQuery) async throws -> NoteListResult {
        queries.append(query)
        return results.removeFirst()
    }
}

private struct ReturningUpdateNoteUseCase: UpdateNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String, title: String, content: String) async throws -> Note {
        Note(
            id: noteId, researchSpaceId: spaceId, title: title,
            originType: .userCreated, content: content, createdAt: .now,
            updatedAt: .now, citationCount: nil
        )
    }
}

private struct ImmediateDeleteNoteUseCase: DeleteNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String) async throws {}
}

private struct UnusedFetchNoteUseCase: FetchNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String) async throws -> Note { fatalError("Unused") }
}

private struct UnusedUpdateNoteUseCase: UpdateNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String, title: String, content: String) async throws -> Note {
        fatalError("Unused")
    }
}
