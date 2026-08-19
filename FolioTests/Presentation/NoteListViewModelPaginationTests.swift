@testable import Folio
import XCTest

@MainActor
final class NoteListViewModelPaginationTests: XCTestCase {
    func testLoadMoreMergesNextPage() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: PaginatedFixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )

        viewModel.handle(.onAppear)
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(viewModel.state.notes.map(\.id), ["p1"])
        XCTAssertEqual(viewModel.state.pagination?.page, 1)
        XCTAssertEqual(viewModel.state.pagination?.totalPages, 2)

        viewModel.handle(.loadMore)
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(viewModel.state.notes.map(\.id), ["p1", "p2"])
        XCTAssertEqual(viewModel.state.pagination?.page, 2)
        XCTAssertNil(viewModel.state.paginationErrorMessage)
    }

    func testLoadMoreFailureSetsPaginationError() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FailingLoadMoreFixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )

        viewModel.handle(.onAppear)
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(viewModel.state.notes.map(\.id), ["p1"])

        viewModel.handle(.loadMore)
        await Task.yield()
        await Task.yield()

        XCTAssertNotNil(viewModel.state.paginationErrorMessage)
        XCTAssertEqual(viewModel.state.notes.map(\.id), ["p1"])
        XCTAssertFalse(viewModel.state.isLoadingNextPage)
    }

    func testSuccessfulRefreshClearsPreviousPaginationError() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FailingLoadMoreFixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )

        viewModel.handle(.onAppear)
        await Task.yield()
        await Task.yield()
        viewModel.handle(.loadMore)
        await Task.yield()
        await Task.yield()

        XCTAssertNotNil(viewModel.state.paginationErrorMessage)

        viewModel.handle(.refresh)
        await Task.yield()
        await Task.yield()

        XCTAssertNil(viewModel.state.paginationErrorMessage)
        XCTAssertEqual(viewModel.state.notes.map(\.id), ["p1"])
    }

    func testCancellationErrorDuringRefreshDoesNotSetErrorMessage() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: ThrowingNotesUseCase(error: CancellationError()),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )

        viewModel.handle(.refresh)
        await Task.yield()
        await Task.yield()

        XCTAssertNil(viewModel.state.errorMessage)
        XCTAssertFalse(viewModel.state.isLoading)
    }

    func testURLErrorCancelledDuringRefreshDoesNotSetErrorMessage() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: ThrowingNotesUseCase(error: URLError(.cancelled)),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )

        viewModel.handle(.refresh)
        await Task.yield()
        await Task.yield()

        XCTAssertNil(viewModel.state.errorMessage)
        XCTAssertFalse(viewModel.state.isLoading)
    }

    func testNonCancellationErrorDuringRefreshSetsErrorMessage() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: ThrowingNotesUseCase(error: NetworkError.httpError(statusCode: 500)),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )

        viewModel.handle(.refresh)
        await Task.yield()
        await Task.yield()

        XCTAssertNotNil(viewModel.state.errorMessage)
        XCTAssertFalse(viewModel.state.isLoading)
    }

    func testFailedRefreshPreservesPreviouslyLoadedNotes() async {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: FailAfterFirstFixtureNotesUseCase(),
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )

        viewModel.handle(.onAppear)
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(viewModel.state.notes.map(\.id), ["p1"])

        viewModel.handle(.refresh)
        await Task.yield()
        await Task.yield()

        XCTAssertNotNil(viewModel.state.errorMessage)
        XCTAssertEqual(viewModel.state.notes.map(\.id), ["p1"])
    }

    func testClearingSearchReloadsImmediatelyWithoutWaitingForDebounce() async {
        let fetch = GatedSearchNotesUseCase()
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: fetch,
            fetchNoteUseCase: UnusedFixtureNoteUseCase(),
            updateNoteUseCase: UnusedFixtureUpdateUseCase(),
            deleteNoteUseCase: UnusedFixtureDeleteUseCase()
        )

        viewModel.handle(.onAppear)
        await waitForTasks()

        XCTAssertEqual(viewModel.state.notes.map(\.id), ["n1"])

        viewModel.handle(.searchChanged("nomatch"))
        try? await Task.sleep(nanoseconds: 350_000_000)
        await waitForTasks()

        XCTAssertTrue(viewModel.state.notes.isEmpty)
        XCTAssertEqual(viewModel.state.searchQuery, "nomatch")

        fetch.gateEnabled = true
        viewModel.handle(.searchChanged(""))
        await Task.yield()

        XCTAssertTrue(fetch.clearLoadStarted)
        XCTAssertTrue(viewModel.state.isLoading)

        fetch.gateEnabled = false
        fetch.release()
        await waitForTasks()

        XCTAssertEqual(viewModel.state.notes.map(\.id), ["n1"])
        XCTAssertEqual(viewModel.state.searchQuery, "")
    }

    private func waitForTasks() async {
        for _ in 0..<20 { await Task.yield() }
    }

    func testRefreshFailureWithExistingNotesDoesNotUseFullErrorState() {
        XCTAssertTrue(NoteListView.showsFullError(errorMessage: "Failed to load notes", notes: []))
        XCTAssertFalse(
            NoteListView.showsFullError(
                errorMessage: "Failed to load notes",
                notes: [
                    NoteSummary(
                        id: "p1", researchSpaceId: "space-1", title: "Page 1",
                        originType: .userCreated, contentPreview: "",
                        createdAt: .now, updatedAt: .now, citationCount: nil
                    )
                ]
            )
        )
    }
}

private struct PaginatedFixtureNotesUseCase: FetchNotesUseCaseProtocol {
    func execute(query: NoteListQuery) async throws -> NoteListResult {
        if query.page == nil {
            return NoteListResult(
                notes: [
                    note(id: "p1", title: "Page 1", updatedAt: Date())
                ],
                pagination: NotePagination(page: 1, limit: 10, totalCount: 2, totalPages: 2)
            )
        }
        return NoteListResult(
            notes: [
                note(id: "p2", title: "Page 2", updatedAt: Date(timeIntervalSince1970: 0))
            ],
            pagination: NotePagination(page: 2, limit: 10, totalCount: 2, totalPages: 2)
        )
    }

    private func note(id: String, title: String, updatedAt: Date = Date()) -> NoteSummary {
        NoteSummary(
            id: id, researchSpaceId: "space-1", title: title,
            originType: .userCreated, contentPreview: "",
            createdAt: .now, updatedAt: updatedAt, citationCount: nil
        )
    }
}

private struct FailingLoadMoreFixtureNotesUseCase: FetchNotesUseCaseProtocol {
    func execute(query: NoteListQuery) async throws -> NoteListResult {
        if query.page == nil {
            return NoteListResult(
                notes: [
                    NoteSummary(
                        id: "p1", researchSpaceId: "space-1", title: "Page 1",
                        originType: .userCreated, contentPreview: "",
                        createdAt: .now, updatedAt: .now, citationCount: nil
                    )
                ],
                pagination: NotePagination(page: 1, limit: 10, totalCount: 2, totalPages: 2)
            )
        }
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
    }
}

private struct ThrowingNotesUseCase: FetchNotesUseCaseProtocol {
    let error: Error
    func execute(query: NoteListQuery) async throws -> NoteListResult {
        throw error
    }
}

@MainActor
private final class GatedSearchNotesUseCase: FetchNotesUseCaseProtocol {
    private(set) var clearLoadStarted = false
    var gateEnabled = false
    private var resume: CheckedContinuation<Void, Never>?

    func execute(query: NoteListQuery) async throws -> NoteListResult {
        if query.search == nil {
            if gateEnabled {
                clearLoadStarted = true
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    resume = continuation
                }
                resume = nil
            }
            return NoteListResult(
                notes: [NoteSummary(
                    id: "n1", researchSpaceId: "space-1", title: "Note",
                    originType: .userCreated, contentPreview: "",
                    createdAt: .now, updatedAt: .now, citationCount: nil
                )],
                pagination: nil
            )
        }
        return NoteListResult(notes: [], pagination: nil)
    }

    func release() {
        resume?.resume()
    }
}

@MainActor
private final class FailAfterFirstFixtureNotesUseCase: FetchNotesUseCaseProtocol {
    private var hasLoadedOnce = false

    func execute(query: NoteListQuery) async throws -> NoteListResult {
        if hasLoadedOnce {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Reload error"])
        }
        hasLoadedOnce = true
        return NoteListResult(
            notes: [
                NoteSummary(
                    id: "p1", researchSpaceId: "space-1", title: "Page 1",
                    originType: .userCreated, contentPreview: "",
                    createdAt: .now, updatedAt: .now, citationCount: nil
                )
            ],
            pagination: nil
        )
    }
}
