@testable import Folio
import XCTest

@MainActor
final class NoteListViewModelDeleteEditTests: XCTestCase {
    func testDismissingDeleteConfirmationClearsPendingNote() {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )
        let note = NoteSummary(
            id: "note-1",
            researchSpaceId: "space-1",
            title: "Note",
            originType: .userCreated,
            contentPreview: "",
            createdAt: .now,
            updatedAt: .now,
            citationCount: nil
        )

        viewModel.handle(.deleteRequested(note))
        viewModel.handle(.dismissDeleteConfirmation)

        XCTAssertNil(viewModel.state.pendingDelete)
    }

    func testDeletingNoteFromEditSheetDismissesSheetImmediately() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )
        let note = makeNote(citationCount: nil)

        viewModel.handle(.editStarted(note))
        viewModel.handle(.deleteRequested(note.summary))

        XCTAssertNil(viewModel.state.sheet)
        XCTAssertNil(viewModel.state.pendingDelete)

        viewModel.handle(.sheetDismissed)

        viewModel.handle(.deleteConfirmed)
        await Task.yield()
        await Task.yield()

        XCTAssertNil(viewModel.state.pendingDelete)
    }

    func testRequestingDeleteFromEditSheetDismissesSheetBeforeConfirmation() {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )
        let note = makeNote(citationCount: nil)

        viewModel.handle(.editStarted(note))
        viewModel.handle(.editTitleChanged("Draft title"))
        viewModel.handle(.deleteRequested(note.summary))

        XCTAssertNil(viewModel.state.sheet)
        XCTAssertNil(viewModel.state.pendingDelete)

        viewModel.handle(.sheetDismissed)

        XCTAssertEqual(viewModel.state.pendingDelete?.id, note.id)
        XCTAssertEqual(viewModel.state.editTitle, "Draft title")
    }

    func testEmptyEditTitleDoesNotStartSave() {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )
        let note = makeNote(citationCount: nil)

        viewModel.handle(.editStarted(note))
        viewModel.handle(.editTitleChanged("   "))
        viewModel.handle(.editSaved(note))

        XCTAssertFalse(viewModel.state.isSaving)
    }
}
