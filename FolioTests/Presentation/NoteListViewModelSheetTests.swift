@testable import Folio
import XCTest

@MainActor
final class NoteListViewModelSheetTests: XCTestCase {
    func testSelectingNoteLoadsFullDetailIntoSharedSheetState() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: FixtureDetailNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )
        let summary = NoteSummary(
            id: "note-1",
            researchSpaceId: "space-1",
            title: "Summary title",
            originType: .userCreated,
            contentPreview: "Preview",
            createdAt: .now,
            updatedAt: .now,
            citationCount: 2
        )

        viewModel.handle(.noteSelected(summary))
        await Task.yield()
        await Task.yield()

        guard case .detail(let note) = viewModel.state.sheet else {
            return XCTFail("Expected the shared detail sheet state")
        }
        XCTAssertEqual(note.title, "Full title")
        XCTAssertEqual(note.content, "Full content")
    }

    func testRequestingNoteActionsPresentsActionSheetWithoutLoadingDetail() {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )
        let summary = makeSummary()

        viewModel.handle(.noteActionsRequested(summary))

        guard case .actions(let presentedNote) = viewModel.state.sheet else {
            return XCTFail("Expected the note action sheet state")
        }
        XCTAssertEqual(presentedNote.id, summary.id)
    }

    func testViewActionDismissesActionSheetAndLoadsDetail() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: FixtureDetailNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )
        let summary = makeSummary()

        viewModel.handle(.noteActionsRequested(summary))
        viewModel.handle(.viewRequested(summary))
        await Task.yield()
        await Task.yield()

        guard case .detail(let note) = viewModel.state.sheet else {
            return XCTFail("Expected the detail sheet state")
        }
        XCTAssertEqual(note.id, summary.id)
    }

    func testDeleteActionPresentsConfirmationAfterActionSheetDismisses() {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )
        let summary = makeSummary()

        viewModel.handle(.noteActionsRequested(summary))
        viewModel.handle(.deleteRequestedFromActionSheet(summary))

        XCTAssertNil(viewModel.state.sheet)
        XCTAssertNil(viewModel.state.pendingDelete)

        viewModel.handle(.sheetDismissed)

        XCTAssertEqual(viewModel.state.pendingDelete?.id, summary.id)
    }

    func testConvertingNoteLoadsFullDetailIntoConversionSheetState() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: FixtureDetailNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )
        let summary = NoteSummary(
            id: "note-1",
            researchSpaceId: "space-1",
            title: "Summary title",
            originType: .userCreated,
            contentPreview: "Preview",
            createdAt: .now,
            updatedAt: .now,
            citationCount: 2
        )

        viewModel.handle(.convertTapped(summary))
        await Task.yield()
        await Task.yield()

        guard case .convert(let note) = viewModel.state.sheet else {
            return XCTFail("Expected the conversion sheet state")
        }
        XCTAssertEqual(note.title, "Full title")
    }

    func testConvertingNoteFailureKeepsSheetClosedAndShowsError() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: FailingFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )
        let summary = NoteSummary(
            id: "note-1",
            researchSpaceId: "space-1",
            title: "Summary title",
            originType: .userCreated,
            contentPreview: "Preview",
            createdAt: .now,
            updatedAt: .now,
            citationCount: nil
        )

        viewModel.handle(.convertTapped(summary))
        await Task.yield()
        await Task.yield()

        XCTAssertNil(viewModel.state.sheet)
        XCTAssertEqual(viewModel.state.toast?.text, String(localized: "Failed to fetch note. Please try again."))
    }
}

private func makeSummary() -> NoteSummary {
    NoteSummary(
        id: "note-1",
        researchSpaceId: "space-1",
        title: "Summary title",
        originType: .userCreated,
        contentPreview: "Preview",
        createdAt: .now,
        updatedAt: .now,
        citationCount: 2
    )
}

private struct FixtureDetailNoteUseCase: FetchNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String) async throws -> Note {
        Note(
            id: noteId,
            researchSpaceId: spaceId,
            title: "Full title",
            originType: .userCreated,
            content: "Full content",
            createdAt: .now,
            updatedAt: .now,
            citationCount: 2
        )
    }
}

private struct FailingFixtureNoteUseCase: FetchNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String) async throws -> Note {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Conversion error"])
    }
}
