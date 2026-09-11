@testable import Folio
import XCTest

@MainActor
final class NoteListViewModelSheetTests: XCTestCase {
    func testProcessingSourceDeletionNotifiesSourceList() {
        let viewModel = makeViewModel()
        var sourceListRefreshCount = 0
        viewModel.onSourcesChanged = { sourceListRefreshCount += 1 }

        viewModel.handle(.processingSourceDeleted)

        XCTAssertEqual(sourceListRefreshCount, 1)
    }

    func testProcessingSourceStatusChangeNotifiesSourceList() {
        let viewModel = makeViewModel()
        var sourceListRefreshCount = 0
        viewModel.onSourcesChanged = { sourceListRefreshCount += 1 }

        viewModel.handle(.processingSourceStatusChanged)

        XCTAssertEqual(sourceListRefreshCount, 1)
    }

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

    private func makeViewModel() -> NoteListViewModel {
        NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )
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

    func testBlankConversionTitleKeepsConversionSheetOpen() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: FixtureDetailNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )

        viewModel.handle(.convertTapped(makeSummary()))
        await Task.yield()
        await Task.yield()
        viewModel.handle(.convertConfirmed("   "))

        guard case .convert = viewModel.state.sheet else {
            return XCTFail("Expected the conversion form to remain open for a blank title")
        }
    }

    func testConversionPresentsProcessingSheetForCreatedSource() async {
        let conversion = FixtureConvertNoteToSourceUseCase()
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: FixtureDetailNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            convertNoteToSourceUseCase: conversion,
            uploadSourceUseCase: FixtureUploadSourceUseCase()
        )

        viewModel.handle(.convertTapped(makeSummary()))
        await Task.yield()
        await Task.yield()
        viewModel.handle(.convertConfirmed("  Snapshot title  "))
        await conversion.waitUntilCalled()
        await Task.yield()

        guard case .processing(let source) = viewModel.state.sheet else {
            return XCTFail("Expected the returned source to open the processing sheet")
        }
        XCTAssertEqual(source.id, "source-1")
        XCTAssertEqual(conversion.receivedTitle, "Snapshot title")
        XCTAssertEqual(viewModel.state.toast, .success(String(localized: "Source created")))
    }

    func testSuccessfulConversionTriggersSourcesRefreshCallback() async {
        let conversion = FixtureConvertNoteToSourceUseCase()
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: FixtureDetailNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            convertNoteToSourceUseCase: conversion,
            uploadSourceUseCase: FixtureUploadSourceUseCase()
        )
        let expectation = expectation(description: "Sources refresh callback invoked")
        viewModel.onSourcesChanged = { expectation.fulfill() }

        viewModel.handle(.convertTapped(makeSummary()))
        await Task.yield()
        await Task.yield()
        viewModel.handle(.convertConfirmed("Snapshot title"))
        await conversion.waitUntilCalled()
        await Task.yield()

        await fulfillment(of: [expectation], timeout: 1)
    }

    func testFailedConversionDoesNotTriggerSourcesRefreshCallback() async {
        let conversion = FailingFixtureConvertNoteToSourceUseCase()
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: FixtureDetailNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            convertNoteToSourceUseCase: conversion,
            uploadSourceUseCase: FixtureUploadSourceUseCase()
        )
        var refreshCount = 0
        viewModel.onSourcesChanged = { refreshCount += 1 }

        viewModel.handle(.convertTapped(makeSummary()))
        await Task.yield()
        await Task.yield()
        viewModel.handle(.convertConfirmed("Snapshot title"))
        await conversion.waitUntilCalled()
        await Task.yield()

        XCTAssertEqual(refreshCount, 0)
    }

    func testConversionFailureKeepsConversionSheetOpenAndShowsError() async {
        let conversion = FailingFixtureConvertNoteToSourceUseCase()
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: FixtureDetailNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            convertNoteToSourceUseCase: conversion,
            uploadSourceUseCase: FixtureUploadSourceUseCase()
        )

        viewModel.handle(.convertTapped(makeSummary()))
        await Task.yield()
        await Task.yield()
        viewModel.handle(.convertConfirmed("Snapshot title"))
        await conversion.waitUntilCalled()
        await Task.yield()

        guard case .convert = viewModel.state.sheet else {
            return XCTFail("Expected the conversion form to remain open after an API failure")
        }
        XCTAssertEqual(
            viewModel.state.toast,
            .error(String(localized: "Failed to create source. Please try again."))
        )
    }

    func testConversionFailureShowsServerMessageWhenAvailable() async {
        let conversion = ConversionFailedFixtureConvertNoteToSourceUseCase()
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: FixtureDetailNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            convertNoteToSourceUseCase: conversion,
            uploadSourceUseCase: FixtureUploadSourceUseCase()
        )

        viewModel.handle(.convertTapped(makeSummary()))
        await Task.yield()
        await Task.yield()
        viewModel.handle(.convertConfirmed("Snapshot title"))
        await conversion.waitUntilCalled()
        await Task.yield()

        XCTAssertEqual(
            viewModel.state.toast,
            .error(NoteRepositoryError.conversionFailed("Source snapshot already exists").errorDescription!)
        )
    }

    func testNewActionPresentsEmptyCreateSheet() {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            createNoteUseCase: FixtureCreateNoteUseCase()
        )

        viewModel.handle(.newTapped)

        XCTAssertEqual(viewModel.state.sheet, .create)
        XCTAssertTrue(viewModel.state.createTitle.isEmpty)
        XCTAssertTrue(viewModel.state.createContent.isEmpty)
    }

    func testCreateSaveUsesUntitledFallbackAndRefreshesNotes() async {
        let fetchNotes = FixtureNotesUseCase()
        let createNote = FixtureCreateNoteUseCase()
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: fetchNotes,
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            createNoteUseCase: createNote
        )

        viewModel.handle(.newTapped)
        viewModel.handle(.createTitleChanged("   "))
        viewModel.handle(.createContentChanged("Body"))
        viewModel.handle(.createSaveTapped)
        await createNote.waitUntilCalled()
        await Task.yield()

        XCTAssertEqual(createNote.title, "Untitled Note")
        XCTAssertEqual(createNote.content, "Body")
        XCTAssertNil(viewModel.state.sheet)
        XCTAssertEqual(viewModel.state.toast?.text, String(localized: "Note saved"))
        XCTAssertGreaterThanOrEqual(fetchNotes.requestCount, 1)
    }

    func testInvalidCreateContentDoesNotSubmit() {
        let createNote = FixtureCreateNoteUseCase()
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            createNoteUseCase: createNote
        )

        viewModel.handle(.newTapped)
        viewModel.handle(.createContentChanged("<ol><li></li></ol>"))
        viewModel.handle(.createSaveTapped)

        XCTAssertEqual(viewModel.state.createContentError, "Content cannot be empty")
        XCTAssertFalse(createNote.wasCalled)
    }

    func testCreateDraftShowsLimitErrorsWhileEditing() {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            createNoteUseCase: FixtureCreateNoteUseCase()
        )

        viewModel.handle(.newTapped)
        viewModel.handle(.createTitleChanged(String(repeating: "t", count: NoteLimits.maximumTitleLength + 1)))
        viewModel.handle(.createContentChanged(String(repeating: "c", count: NoteLimits.maximumContentLength + 1)))
        viewModel.handle(.createContentEditingEnded)

        XCTAssertEqual(
            viewModel.state.createTitleError,
            String.localizedStringWithFormat(
                String(localized: "Title cannot exceed %@ characters"),
                NoteLimits.maximumTitleLengthLabel
            )
        )
        XCTAssertEqual(
            viewModel.state.createContentError,
            String.localizedStringWithFormat(
                String(localized: "Content exceeds maximum length of %@ characters"),
                NoteLimits.maximumContentLengthLabel
            )
        )
    }

    func testCreateFailurePreservesDraftAndShowsError() async {
        let createNote = FailingFixtureCreateNoteUseCase()
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            createNoteUseCase: createNote
        )

        viewModel.handle(.newTapped)
        viewModel.handle(.createContentChanged("Draft"))
        viewModel.handle(.createSaveTapped)
        await createNote.waitUntilCalled()
        await Task.yield()

        XCTAssertEqual(viewModel.state.sheet, .create)
        XCTAssertEqual(viewModel.state.createContent, "Draft")
        XCTAssertEqual(viewModel.state.toast?.text, String(localized: "Failed to create note. Please try again."))
    }

    func testCreateDraftCannotChangeWhileSaveIsInFlight() async {
        let createNote = ControlledCreateNoteUseCase()
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            createNoteUseCase: createNote
        )

        viewModel.handle(.newTapped)
        viewModel.handle(.createTitleChanged("Original title"))
        viewModel.handle(.createContentChanged("Original content"))
        viewModel.handle(.createSaveTapped)
        await createNote.waitUntilCalled()

        viewModel.handle(.createTitleChanged("Late title"))
        viewModel.handle(.createContentChanged("Late content"))

        XCTAssertEqual(viewModel.state.createTitle, "Original title")
        XCTAssertEqual(viewModel.state.createContent, "Original content")
        createNote.resumeWithFailure()
    }

    func testCancelWithCreateDraftRequestsDiscardConfirmation() {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            createNoteUseCase: FixtureCreateNoteUseCase()
        )

        viewModel.handle(.newTapped)
        viewModel.handle(.createContentChanged("Draft"))
        viewModel.handle(.createCancelTapped)

        XCTAssertTrue(viewModel.state.isDiscardCreateDraftPresented)
        XCTAssertEqual(viewModel.state.sheet, .create)

        viewModel.handle(.createDiscardCancelled)
        XCTAssertFalse(viewModel.state.isDiscardCreateDraftPresented)
        XCTAssertEqual(viewModel.state.sheet, .create)

        viewModel.handle(.createCancelTapped)
        viewModel.handle(.createDiscardConfirmed)
        XCTAssertNil(viewModel.state.sheet)
        XCTAssertTrue(viewModel.state.createContent.isEmpty)
    }

    func testInteractiveDismissAttemptWithCreateDraftRequestsDiscardConfirmation() {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            createNoteUseCase: FixtureCreateNoteUseCase()
        )

        viewModel.handle(.newTapped)
        viewModel.handle(.createContentChanged("Draft"))
        viewModel.handle(.createDismissalAttempted)

        XCTAssertTrue(viewModel.state.isDiscardCreateDraftPresented)
        XCTAssertEqual(viewModel.state.sheet, .create)

        viewModel.handle(.createDiscardCancelled)
        XCTAssertFalse(viewModel.state.isDiscardCreateDraftPresented)
        XCTAssertEqual(viewModel.state.sheet, .create)

        viewModel.handle(.createDismissalAttempted)
        viewModel.handle(.createDiscardConfirmed)
        XCTAssertNil(viewModel.state.sheet)
        XCTAssertTrue(viewModel.state.createContent.isEmpty)
    }

    func testCreateDismissalAttemptIgnoredWhileSaving() async {
        let createNote = ControlledCreateNoteUseCase()
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase(),
            createNoteUseCase: createNote
        )

        viewModel.handle(.newTapped)
        viewModel.handle(.createContentChanged("Draft"))
        viewModel.handle(.createSaveTapped)
        await createNote.waitUntilCalled()

        viewModel.handle(.createDismissalAttempted)

        XCTAssertFalse(viewModel.state.isDiscardCreateDraftPresented)
        XCTAssertEqual(viewModel.state.sheet, .create)
        createNote.resumeWithFailure()
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

@MainActor
private final class FailingFixtureCreateNoteUseCase: CreateNoteUseCaseProtocol {
    private var called = false

    func execute(spaceId: String, title: String, content: String) async throws -> Note {
        called = true
        throw NSError(domain: "test", code: 1)
    }

    func waitUntilCalled() async {
        while !called {
            await Task.yield()
        }
    }
}

@MainActor
private final class ControlledCreateNoteUseCase: CreateNoteUseCaseProtocol {
    private var continuation: CheckedContinuation<Note, Error>?
    private var called = false

    func execute(spaceId: String, title: String, content: String) async throws -> Note {
        called = true
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilCalled() async {
        while !called {
            await Task.yield()
        }
    }

    func resumeWithFailure() {
        continuation?.resume(throwing: NSError(domain: "test", code: 1))
        continuation = nil
    }
}

@MainActor
private final class FixtureConvertNoteToSourceUseCase: ConvertNoteToSourceUseCaseProtocol {
    private(set) var receivedTitle: String?

    func execute(spaceId: String, noteId: String, title: String) async throws -> Source {
        receivedTitle = title
        return makeConvertedSource(spaceId: spaceId)
    }

    func waitUntilCalled() async {
        while receivedTitle == nil {
            await Task.yield()
        }
    }
}

@MainActor
private final class FailingFixtureConvertNoteToSourceUseCase: ConvertNoteToSourceUseCaseProtocol {
    private var called = false

    func execute(spaceId: String, noteId: String, title: String) async throws -> Source {
        called = true
        throw NSError(domain: "test", code: 1)
    }

    func waitUntilCalled() async {
        while !called {
            await Task.yield()
        }
    }
}

private final class ConversionFailedFixtureConvertNoteToSourceUseCase: ConvertNoteToSourceUseCaseProtocol {
    private var called = false

    func execute(spaceId: String, noteId: String, title: String) async throws -> Source {
        called = true
        throw NoteRepositoryError.conversionFailed("Source snapshot already exists")
    }

    func waitUntilCalled() async {
        while !called {
            await Task.yield()
        }
    }
}

private struct FixtureUploadSourceUseCase: UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source {
        makeConvertedSource(spaceId: spaceId)
    }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source {
        makeConvertedSource(spaceId: spaceId)
    }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source {
        makeConvertedSource(spaceId: spaceId)
    }
    func deleteSource(id: String) async throws {}
    func retrySource(id: String) async throws -> Source { makeConvertedSource(spaceId: "space-1") }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private func makeConvertedSource(spaceId: String) -> Source {
    Source(
        id: "source-1", researchSpaceId: spaceId, sourceType: .manual, title: "Snapshot title",
        author: "", sourceUrl: "", fileName: "", fileSize: 0, fileType: "", pageCount: 0,
        characterCount: 0, content: "", structuredContent: nil, processingState: .added,
        processingError: "", createdAt: .now, updatedAt: .now
    )
}
