import XCTest
@testable import Folio

@MainActor
final class SourceListMutationConsistencyTests: XCTestCase {
    func testStaleListResponseDoesNotOverwriteEdit() async {
        let initial = source(id: "one", title: "Original")
        let stale = source(id: "one", title: "Original")
        let fetch = GatedFetchSourcesUseCase(results: [
            SourceListResult(sources: [initial], pagination: nil),
            SourceListResult(sources: [stale], pagination: nil)
        ])
        let update = ReturningUpdateSourceUseCase()
        let viewModel = makeViewModel(fetch: fetch, update: update)

        viewModel.send(.appeared)
        await fetch.waitUntilBlocked()
        fetch.releaseNext()
        await waitForTasks()

        XCTAssertEqual(viewModel.state.allSources.first?.title, "Original")

        viewModel.send(.refresh)
        await fetch.waitUntilBlocked()

        viewModel.send(.ellipsisTapped(initial))
        viewModel.editTitle = "Edited"
        viewModel.editAuthor = "Author"
        viewModel.send(.editConfirmed)
        await waitForTasks()

        fetch.releaseNext()
        await waitForTasks()

        XCTAssertEqual(fetch.requestCount, 2)
        XCTAssertEqual(viewModel.state.allSources.first?.title, "Edited")
    }

    func testStaleListResponseDoesNotRestoreDeletedSource() async {
        let doomed = source(id: "one", title: "Doomed")
        let stale = source(id: "one", title: "Doomed")
        let fetch = GatedFetchSourcesUseCase(results: [
            SourceListResult(sources: [doomed], pagination: nil),
            SourceListResult(sources: [stale], pagination: nil)
        ])
        let upload = RecordingDeleteUploadSourceUseCase()
        let viewModel = makeViewModel(fetch: fetch, upload: upload)

        viewModel.send(.appeared)
        await fetch.waitUntilBlocked()
        fetch.releaseNext()
        await waitForTasks()

        XCTAssertEqual(viewModel.state.allSources.count, 1)

        viewModel.send(.refresh)
        await fetch.waitUntilBlocked()

        viewModel.send(.deleteTapped(doomed))
        viewModel.send(.deleteConfirmed)
        await waitForTasks()

        fetch.releaseNext()
        await waitForTasks()

        XCTAssertEqual(viewModel.state.allSources.count, 0)
    }

    func testProcessingSourceTapPresentsProcessingSheet() async {
        let processing = source(id: "proc", title: "Processing", state: .added)
        let viewModel = makeViewModel(fetch: FailingFetchSourcesUseCase())

        viewModel.send(.sourceTapped(processing))
        await waitForTasks()

        guard case .processing(let presented)? = viewModel.state.presentedSheet else {
            XCTFail("Expected processing sheet")
            return
        }
        XCTAssertEqual(presented.id, "proc")
    }

    func testFailedSourceTapPresentsFailureSheet() async {
        let failed = source(id: "failed", title: "Failed", state: .failed)
        let viewModel = makeViewModel(fetch: FailingFetchSourcesUseCase())

        viewModel.send(.sourceTapped(failed))
        await waitForTasks()

        guard case .failure(let presented)? = viewModel.state.presentedSheet else {
            XCTFail("Expected failure sheet")
            return
        }
        XCTAssertEqual(presented.id, "failed")
    }

    func testReadySourceTapDoesNotPresentSheet() async {
        let ready = source(id: "ready", title: "Ready", state: .ready)
        let viewModel = makeViewModel(fetch: FailingFetchSourcesUseCase())

        viewModel.send(.sourceTapped(ready))
        await waitForTasks()

        XCTAssertNil(viewModel.state.presentedSheet)
    }

    func testDismissSheetClearsProcessingSheet() async {
        let processing = source(id: "proc", title: "Processing", state: .added)
        let viewModel = makeViewModel(fetch: FailingFetchSourcesUseCase())

        viewModel.send(.sourceTapped(processing))
        await waitForTasks()
        XCTAssertNotNil(viewModel.state.presentedSheet)

        viewModel.send(.dismissSheet)
        await waitForTasks()

        XCTAssertNil(viewModel.state.presentedSheet)
    }

    func testSourceDeletedFromProcessingRemovesSource() async {
        let failed = source(id: "failed", title: "Failed", state: .failed)
        let fetch = GatedFetchSourcesUseCase(results: [SourceListResult(sources: [failed], pagination: nil)])
        let viewModel = makeViewModel(fetch: fetch)

        viewModel.send(.appeared)
        await fetch.waitUntilBlocked()
        fetch.releaseNext()
        await waitForTasks()

        XCTAssertEqual(viewModel.state.allSources.count, 1)
        XCTAssertEqual(viewModel.state.totalCount, 1)

        viewModel.send(.sourceDeletedFromProcessing(failed))

        XCTAssertNil(viewModel.state.presentedSheet)
        XCTAssertEqual(viewModel.state.allSources.count, 0)
        XCTAssertEqual(viewModel.state.totalCount, 0)
        XCTAssertNotNil(viewModel.state.toastMessage)
    }

    func testSourceStatusChangedUpdatesListEntry() async {
        let processing = source(id: "proc", title: "Processing", state: .added)
        let fetch = GatedFetchSourcesUseCase(results: [SourceListResult(sources: [processing], pagination: nil)])
        let viewModel = makeViewModel(fetch: fetch)

        viewModel.send(.appeared)
        await fetch.waitUntilBlocked()
        fetch.releaseNext()
        await waitForTasks()

        XCTAssertEqual(viewModel.state.allSources.count, 1)

        let updated = processing.withProcessingState(.ready)
        viewModel.send(.sourceStatusChanged(updated))

        XCTAssertEqual(viewModel.state.allSources.first?.processingState, .ready)
    }

    private func makeViewModel(
        fetch: FetchSourcesUseCaseProtocol,
        update: UpdateSourceUseCaseProtocol = FailingUpdateSourceUseCase(),
        upload: UploadSourceUseCaseProtocol = StubUploadSourceUseCase()
    ) -> SourceListViewModel {
        SourceListViewModel(
            spaceId: "space-1",
            fetchSourcesUseCase: fetch,
            updateSourceUseCase: update,
            uploadSourceUseCase: upload
        )
    }

    private func source(id: String, title: String, state: SourceProcessingState = .ready) -> Source {
        Source(
            id: id,
            researchSpaceId: "space-1",
            sourceType: .web,
            title: title,
            author: "Author",
            sourceUrl: "https://example.com",
            fileName: "",
            fileSize: 0,
            fileType: "",
            pageCount: 0,
            characterCount: 0,
            content: "",
            structuredContent: nil,
            processingState: state,
            processingError: "",
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func waitForTasks() async {
        await Task.yield()
        await Task.yield()
    }
}

@MainActor
private final class GatedFetchSourcesUseCase: FetchSourcesUseCaseProtocol {
    private let results: [SourceListResult]
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var blockedWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var requestCount = 0

    init(results: [SourceListResult]) {
        self.results = results
    }

    func execute(query: SourceListQuery) async throws -> SourceListResult {
        let index = requestCount
        requestCount += 1
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            continuations.append(continuation)
            let waiters = blockedWaiters
            blockedWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
        return results[index]
    }

    func releaseNext() {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume()
    }

    func waitUntilBlocked() async {
        guard continuations.isEmpty else { return }
        await withCheckedContinuation { blockedWaiters.append($0) }
    }
}

private struct ReturningUpdateSourceUseCase: UpdateSourceUseCaseProtocol {
    func execute(id: String, title: String, author: String) async throws -> Source {
        source(id: id, title: title, author: author)
    }

    private func source(id: String, title: String, author: String) -> Source {
        Source(
            id: id,
            researchSpaceId: "space-1",
            sourceType: .web,
            title: title,
            author: author,
            sourceUrl: "https://example.com",
            fileName: "",
            fileSize: 0,
            fileType: "",
            pageCount: 0,
            characterCount: 0,
            content: "",
            structuredContent: nil,
            processingState: .ready,
            processingError: "",
            createdAt: .now,
            updatedAt: .now
        )
    }
}

private struct FailingUpdateSourceUseCase: UpdateSourceUseCaseProtocol {
    func execute(id: String, title: String, author: String) async throws -> Source { fatalError("Not used") }
}

private struct FailingFetchSourcesUseCase: FetchSourcesUseCaseProtocol {
    func execute(query: SourceListQuery) async throws -> SourceListResult { throw CancellationError() }
}

@MainActor
private final class RecordingDeleteUploadSourceUseCase: UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source { fatalError("Not used") }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source { fatalError("Not used") }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source { fatalError("Not used") }
    func retrySource(id: String) async throws -> Source { fatalError("Not used") }
    func deleteSource(id: String) async throws {}
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private struct StubUploadSourceUseCase: UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source { fatalError("Not used") }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source { fatalError("Not used") }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source { fatalError("Not used") }
    func retrySource(id: String) async throws -> Source { fatalError("Not used") }
    func deleteSource(id: String) async throws { fatalError("Not used") }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}
