@testable import Folio
import XCTest

@MainActor
final class NoteListViewModelConcurrencyTests: XCTestCase {
    func testRecentlyCreatedPreservesTheServerProvidedOrder() async {
        let viewModel = makeViewModel(fetchNotes: SortAwareNotesUseCase())

        viewModel.handle(.sortSelected(.recentlyCreated))
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(viewModel.state.notes.map(\.id), ["newly-created", "older-created"])
    }

    func testStaleListResponseDoesNotResurrectDeletedNote() async {
        let fetchNotes = ControlledNotesUseCase()
        let note = summary()
        let viewModel = makeViewModel(fetchNotes: fetchNotes)

        viewModel.handle(.onAppear)
        await fetchNotes.waitUntilRequested()
        viewModel.handle(.deleteRequested(note))
        viewModel.handle(.deleteConfirmed)
        await fetchNotes.waitUntilRequested(count: 2)
        await fetchNotes.resumeNext(with: NoteListResult(notes: [note], pagination: nil))
        await fetchNotes.resumeNext(with: NoteListResult(notes: [], pagination: nil))
        await Task.yield()

        XCTAssertFalse(viewModel.state.notes.contains { $0.id == note.id })
    }

    func testDeleteConfirmationStartsOnlyOneDeleteRequest() async {
        let deleteNotes = ControlledDeleteNotesUseCase()
        let viewModel = makeViewModel(deleteNotes: deleteNotes)
        let note = summary()

        viewModel.handle(.deleteRequested(note))
        viewModel.handle(.deleteConfirmed)
        await deleteNotes.waitUntilCallCount(reaches: 1)
        viewModel.handle(.deleteConfirmed)
        await Task.yield()

        let deleteCallCount = await deleteNotes.callCount
        XCTAssertEqual(deleteCallCount, 1)
        await deleteNotes.resumeAll()
    }

    func testOlderDetailResponseDoesNotReplaceNewerSelection() async {
        let fetchNote = ControlledDetailNoteUseCase()
        let viewModel = makeViewModel(fetchNote: fetchNote)
        let first = summary(id: "first")
        let second = summary(id: "second")

        viewModel.handle(.noteSelected(first))
        await fetchNote.waitUntilRequested(noteID: first.id)
        viewModel.handle(.noteSelected(second))
        await fetchNote.waitUntilRequested(noteID: second.id)
        await fetchNote.resume(noteID: second.id)
        await Task.yield()
        await fetchNote.resume(noteID: first.id)
        await Task.yield()

        guard case .detail(let note) = viewModel.state.sheet else {
            return XCTFail("Expected the newer detail sheet state")
        }
        XCTAssertEqual(note.id, second.id)
    }

    func testDetailResponseDoesNotReplaceNewlyPresentedSortSheet() async {
        let fetchNote = ControlledDetailNoteUseCase()
        let viewModel = makeViewModel(fetchNote: fetchNote)
        let note = summary()

        viewModel.handle(.noteSelected(note))
        await fetchNote.waitUntilRequested(noteID: note.id)
        viewModel.handle(.sortTapped)
        await fetchNote.resume(noteID: note.id)
        await Task.yield()

        guard case .sortOptions = viewModel.state.sheet else {
            return XCTFail("Expected the sort sheet to remain presented")
        }
    }

    func testDetailResponseDoesNotPresentAfterSheetDismissal() async {
        let fetchNote = ControlledDetailNoteUseCase()
        let viewModel = makeViewModel(fetchNote: fetchNote)
        let note = summary()

        viewModel.handle(.noteSelected(note))
        await fetchNote.waitUntilRequested(noteID: note.id)
        viewModel.handle(.dismissSheet)
        await fetchNote.resume(noteID: note.id)
        await Task.yield()

        XCTAssertNil(viewModel.state.sheet)
    }

    private func makeViewModel(
        fetchNotes: any FetchNotesUseCaseProtocol = EmptyNotesUseCase(),
        fetchNote: any FetchNoteUseCaseProtocol = UnusedNoteUseCase(),
        deleteNotes: any DeleteNoteUseCaseProtocol = ImmediateDeleteNotesUseCase()
    ) -> NoteListViewModel {
        NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: fetchNotes,
            fetchNoteUseCase: fetchNote,
            updateNoteUseCase: UnusedUpdateNoteUseCase(),
            deleteNoteUseCase: deleteNotes
        )
    }

    private func summary(id: String = "note-1") -> NoteSummary {
        NoteSummary(
            id: id, researchSpaceId: "space-1", title: id,
            originType: .userCreated, contentPreview: "",
            createdAt: .now, updatedAt: .now, citationCount: nil
        )
    }
}

private struct EmptyNotesUseCase: FetchNotesUseCaseProtocol {
    func execute(query: NoteListQuery) async throws -> NoteListResult {
        NoteListResult(notes: [], pagination: nil)
    }
}

private struct SortAwareNotesUseCase: FetchNotesUseCaseProtocol {
    func execute(query: NoteListQuery) async throws -> NoteListResult {
        NoteListResult(
            notes: [
                note(id: "newly-created", title: "Zebra", createdAt: .now, updatedAt: .distantPast),
                note(id: "older-created", title: "Apple", createdAt: .distantPast, updatedAt: .now)
            ],
            pagination: nil
        )
    }

    private func note(id: String, title: String, createdAt: Date, updatedAt: Date) -> NoteSummary {
        NoteSummary(
            id: id, researchSpaceId: "space-1", title: title,
            originType: .userCreated, contentPreview: "",
            createdAt: createdAt, updatedAt: updatedAt, citationCount: nil
        )
    }
}

private struct UnusedNoteUseCase: FetchNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String) async throws -> Note { fatalError("Unused") }
}

private struct UnusedUpdateNoteUseCase: UpdateNoteUseCaseProtocol {
    func execute(
        spaceId: String,
        noteId: String,
        title: String,
        content: String
    ) async throws -> Note {
        fatalError("Unused")
    }
}

private struct ImmediateDeleteNotesUseCase: DeleteNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String) async throws {}
}

private actor ControlledNotesUseCase: FetchNotesUseCaseProtocol {
    private var continuations: [CheckedContinuation<NoteListResult, Never>] = []

    func execute(query: NoteListQuery) async throws -> NoteListResult {
        await withCheckedContinuation { continuations.append($0) }
    }

    func waitUntilRequested(count: Int = 1) async {
        while continuations.count < count { await Task.yield() }
    }

    func resumeNext(with result: NoteListResult) {
        continuations.removeFirst().resume(returning: result)
    }
}

private actor ControlledDeleteNotesUseCase: DeleteNoteUseCaseProtocol {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private(set) var callCount = 0

    func execute(spaceId: String, noteId: String) async throws {
        callCount += 1
        await withCheckedContinuation { continuations.append($0) }
    }

    func waitUntilCallCount(reaches expectedCount: Int) async {
        while callCount < expectedCount { await Task.yield() }
    }

    func resumeAll() {
        let pendingContinuations = continuations
        continuations.removeAll()
        pendingContinuations.forEach { $0.resume() }
    }
}

private actor ControlledDetailNoteUseCase: FetchNoteUseCaseProtocol {
    private var continuations: [String: CheckedContinuation<Note, Never>] = [:]

    func execute(spaceId: String, noteId: String) async throws -> Note {
        await withCheckedContinuation { continuations[noteId] = $0 }
    }

    func waitUntilRequested(noteID: String) async {
        while continuations[noteID] == nil { await Task.yield() }
    }

    func resume(noteID: String) {
        let note = Note(
            id: noteID, researchSpaceId: "space-1", title: noteID,
            originType: .userCreated, content: "Content",
            createdAt: .now, updatedAt: .now, citationCount: nil
        )
        continuations.removeValue(forKey: noteID)?.resume(returning: note)
    }
}
