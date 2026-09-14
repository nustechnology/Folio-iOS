import XCTest
@testable import Folio

@MainActor
final class FolioAddSourceViewModelTests: XCTestCase {

    func testConfirmCancelProcessingDeletesInFlightSource() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .added))]
        let viewModel = makeViewModel(mock: mock)
        submitManualSource(viewModel)
        await drain()

        XCTAssertTrue(viewModel.state.isProcessing)
        XCTAssertEqual(viewModel.state.processingSourceID, "s1")

        viewModel.handle(.cancelProcessingTapped)
        viewModel.handle(.confirmCancelProcessing)
        await drain()

        XCTAssertEqual(mock.deletedIDs, ["s1"])
        XCTAssertFalse(viewModel.state.isProcessing)
        XCTAssertTrue(viewModel.state.isAddingNewSource)
    }

    func testConfirmCancelProcessingAfterCompletionDoesNotDelete() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .ready))]
        let viewModel = makeViewModel(mock: mock)
        submitManualSource(viewModel)
        await drain()

        XCTAssertTrue(viewModel.state.isProcessingComplete)

        viewModel.handle(.cancelProcessingTapped)
        viewModel.handle(.confirmCancelProcessing)
        await drain()

        XCTAssertTrue(mock.deletedIDs.isEmpty)
        XCTAssertTrue(viewModel.state.isAddingNewSource)
    }

    func testSecondConfirmProcessingDoesNotDuplicateDelete() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .added))]
        mock.suspendDeletes = true
        let viewModel = makeViewModel(mock: mock)
        submitManualSource(viewModel)
        await drain()

        viewModel.handle(.cancelProcessingTapped)
        viewModel.handle(.confirmCancelProcessing)
        await drain()

        viewModel.handle(.cancelProcessingTapped)
        viewModel.handle(.confirmCancelProcessing)
        await drain()

        XCTAssertEqual(mock.deletedIDs, ["s1"])

        mock.resumeDeletes()
        await drain()
    }

    func testShowAddFormDetachesUploadSoNewSourceKeepsItsOwnProgress() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [
            .success(makeSource(id: "s1", state: .added)),
            .success(makeSource(id: "s2", state: .added))
        ]
        let (firstStream, firstContinuation) = AsyncThrowingStream<SourceStatusEvent, Error>.makeStream()
        let (secondStream, secondContinuation) = AsyncThrowingStream<SourceStatusEvent, Error>.makeStream()
        mock.statusStreams = [firstStream, secondStream]

        var completedSourceIDs: [String] = []
        let viewModel = makeViewModel(mock: mock)
        viewModel.onProcessingComplete = { completedSourceIDs.append($0.id) }

        submitManualSource(viewModel)
        await drain()
        XCTAssertEqual(viewModel.state.processingSourceID, "s1")

        viewModel.handle(.showAddForm)
        XCTAssertFalse(viewModel.state.isProcessing)
        XCTAssertTrue(viewModel.state.isAddingNewSource)

        submitManualSource(viewModel)
        await drain()
        XCTAssertEqual(viewModel.state.processingSourceID, "s2")

        firstContinuation.yield(SourceStatusEvent(sourceId: "s1", state: "ready", progress: 100))
        firstContinuation.finish()
        await drain()

        XCTAssertEqual(viewModel.state.processingSourceID, "s2")
        XCTAssertFalse(viewModel.state.isProcessingComplete)
        XCTAssertEqual(completedSourceIDs, ["s1"])

        secondContinuation.finish()
        await drain()
    }

    func testRetryReusesActiveSessionAndStartsProcessing() async {
        let mock = MockUploadSourceUseCase()
        let (retryStream, retryContinuation) = AsyncThrowingStream<SourceStatusEvent, Error>.makeStream()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .failed))]
        mock.retryResults = [.success(makeSource(id: "s1", state: .added))]
        mock.statusStreams = [retryStream]
        let viewModel = makeViewModel(mock: mock)
        submitManualSource(viewModel)
        await drain()

        XCTAssertTrue(viewModel.state.isProcessingFailed)

        viewModel.handle(.retryProcessing)
        await drain()

        XCTAssertEqual(mock.retryCount, 1)
        XCTAssertFalse(viewModel.state.isProcessingFailed)
        XCTAssertEqual(viewModel.state.processingSourceID, "s1")

        retryContinuation.finish()
    }

    private func makeViewModel(mock: MockUploadSourceUseCase) -> FolioAddSourceViewModel {
        FolioAddSourceViewModel(uploadUseCase: mock, spaceId: "space-1")
    }

    private func submitManualSource(_ viewModel: FolioAddSourceViewModel) {
        viewModel.handle(.selectTab(.text))
        viewModel.handle(.manualContentChanged("hello world"))
        viewModel.handle(.addSource)
    }

    private func drain() async {
        for _ in 0..<10 { await Task.yield() }
    }

    private func makeSource(id: String, state: SourceProcessingState) -> Source {
        Source(
            id: id,
            researchSpaceId: "space-1",
            sourceType: .manual,
            title: "Source",
            author: "",
            sourceUrl: "",
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
}

@MainActor
private final class MockUploadSourceUseCase: UploadSourceUseCaseProtocol {
    var uploadResults: [Result<Source, Error>] = []
    var retryResults: [Result<Source, Error>] = []
    var statusStreams: [AsyncThrowingStream<SourceStatusEvent, Error>] = []
    private(set) var deletedIDs: [String] = []
    private(set) var retryCount = 0
    var suspendDeletes = false
    private var deleteContinuations: [CheckedContinuation<Void, Never>] = []

    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source {
        throw CancellationError()
    }

    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source {
        throw CancellationError()
    }

    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source {
        guard !uploadResults.isEmpty else { throw CancellationError() }
        return try uploadResults.removeFirst().get()
    }

    func deleteSource(id: String) async throws {
        deletedIDs.append(id)
        if suspendDeletes {
            await withCheckedContinuation { deleteContinuations.append($0) }
        }
    }

    func retrySource(id: String) async throws -> Source {
        retryCount += 1
        guard !retryResults.isEmpty else { throw CancellationError() }
        return try retryResults.removeFirst().get()
    }

    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> {
        guard !statusStreams.isEmpty else { return AsyncThrowingStream { $0.finish() } }
        return statusStreams.removeFirst()
    }

    func resumeDeletes() {
        deleteContinuations.forEach { $0.resume() }
        deleteContinuations.removeAll()
    }
}
