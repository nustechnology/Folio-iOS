import XCTest
@testable import Folio

@MainActor
final class FolioAddSourceViewModelTests: XCTestCase {

    func testConfirmCancelProcessingDeletesInFlightSource() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .added))]
        let streamStarted = expectation(description: "status stream started")
        mock.onStatusStream = { streamStarted.fulfill() }

        let viewModel = makeViewModel(mock: mock)
        submitManualSource(viewModel)
        await fulfillment(of: [streamStarted], timeout: 1)

        XCTAssertTrue(viewModel.state.isProcessing)
        XCTAssertEqual(viewModel.state.processingSourceID, "s1")

        let deleted = expectation(description: "deleted")
        mock.onDelete = { deleted.fulfill() }
        viewModel.handle(.cancelProcessingTapped)
        viewModel.handle(.confirmCancelProcessing)
        await fulfillment(of: [deleted], timeout: 1)
        await waitUntil { viewModel.state.isAddingNewSource }

        XCTAssertEqual(mock.deletedIDs, ["s1"])
        XCTAssertFalse(viewModel.state.isProcessing)
    }

    func testConfirmCancelProcessingAfterCompletionDoesNotDelete() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .ready))]
        let completed = expectation(description: "completed")
        let viewModel = makeViewModel(mock: mock)
        viewModel.onProcessingComplete = { _ in completed.fulfill() }
        submitManualSource(viewModel)
        await fulfillment(of: [completed], timeout: 1)

        XCTAssertTrue(viewModel.state.isProcessingComplete)

        viewModel.handle(.cancelProcessingTapped)
        viewModel.handle(.confirmCancelProcessing)
        await waitUntil { viewModel.state.isAddingNewSource }

        XCTAssertTrue(mock.deletedIDs.isEmpty)
    }

    func testCancelProcessingDeleteFailureReturnsToAddFormAndReports() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .added))]
        mock.suspendDeletes = true
        mock.deleteError = URLError(.notConnectedToInternet)
        let streamStarted = expectation(description: "status stream started")
        mock.onStatusStream = { streamStarted.fulfill() }
        let deleteStarted = expectation(description: "delete started")
        mock.onDelete = { deleteStarted.fulfill() }
        let failed = expectation(description: "delete failure reported")
        let viewModel = makeViewModel(mock: mock)
        viewModel.onSourceOperationFailed = { _ in failed.fulfill() }
        submitManualSource(viewModel)
        await fulfillment(of: [streamStarted], timeout: 1)

        viewModel.handle(.cancelProcessingTapped)
        viewModel.handle(.confirmCancelProcessing)
        await fulfillment(of: [deleteStarted], timeout: 1)
        XCTAssertTrue(viewModel.state.isAddingNewSource)

        mock.resumeDeletes()
        await fulfillment(of: [failed], timeout: 1)

        XCTAssertTrue(viewModel.state.isAddingNewSource)
        XCTAssertFalse(viewModel.state.isProcessing)
    }

    func testSecondConfirmProcessingDoesNotDuplicateDelete() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .added))]
        mock.suspendDeletes = true
        let streamStarted = expectation(description: "status stream started")
        mock.onStatusStream = { streamStarted.fulfill() }

        let viewModel = makeViewModel(mock: mock)
        submitManualSource(viewModel)
        await fulfillment(of: [streamStarted], timeout: 1)

        let deleted = expectation(description: "deleted")
        mock.onDelete = { deleted.fulfill() }
        viewModel.handle(.cancelProcessingTapped)
        viewModel.handle(.confirmCancelProcessing)
        await fulfillment(of: [deleted], timeout: 1)

        viewModel.handle(.cancelProcessingTapped)
        viewModel.handle(.confirmCancelProcessing)
        await waitUntil { mock.deletedIDs.count == 1 }
        XCTAssertEqual(mock.deletedIDs, ["s1"])

        mock.resumeDeletes()
        await waitUntil { viewModel.state.isAddingNewSource }
    }

    func testDeleteConfirmedDuringInFlightCancelDeleteStillDismisses() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .added))]
        mock.suspendDeletes = true
        let streamStarted = expectation(description: "status stream started")
        mock.onStatusStream = { streamStarted.fulfill() }

        let viewModel = makeViewModel(mock: mock)
        submitManualSource(viewModel)
        await fulfillment(of: [streamStarted], timeout: 1)

        let deleted = expectation(description: "deleted")
        mock.onDelete = { deleted.fulfill() }
        viewModel.handle(.cancelProcessingTapped)
        viewModel.handle(.confirmCancelProcessing)
        await fulfillment(of: [deleted], timeout: 1)

        viewModel.handle(.deleteSourceTapped)
        viewModel.handle(.deleteSourceConfirmed)
        mock.resumeDeletes()
        await waitUntil { viewModel.state.shouldDismiss }

        XCTAssertEqual(mock.deletedIDs, ["s1"])
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

        let firstStarted = expectation(description: "first stream started")
        let secondStarted = expectation(description: "second stream started")
        var streamCount = 0
        mock.onStatusStream = {
            streamCount += 1
            if streamCount == 1 { firstStarted.fulfill() }
            if streamCount == 2 { secondStarted.fulfill() }
        }

        let completed = expectation(description: "detached completion")
        var completedSourceIDs: [String] = []
        let viewModel = makeViewModel(mock: mock)
        viewModel.onProcessingComplete = {
            completedSourceIDs.append($0.id)
            completed.fulfill()
        }

        submitManualSource(viewModel)
        await fulfillment(of: [firstStarted], timeout: 1)
        XCTAssertEqual(viewModel.state.processingSourceID, "s1")

        viewModel.handle(.showAddForm)
        XCTAssertFalse(viewModel.state.isProcessing)
        XCTAssertTrue(viewModel.state.isAddingNewSource)

        submitManualSource(viewModel)
        await fulfillment(of: [secondStarted], timeout: 1)
        XCTAssertEqual(viewModel.state.processingSourceID, "s2")

        firstContinuation.yield(SourceStatusEvent(sourceId: "s1", state: "ready", progress: 100))
        firstContinuation.finish()
        await fulfillment(of: [completed], timeout: 1)

        XCTAssertEqual(viewModel.state.processingSourceID, "s2")
        XCTAssertFalse(viewModel.state.isProcessingComplete)
        XCTAssertEqual(completedSourceIDs, ["s1"])

        secondContinuation.finish()
    }

    func testDetachedUploadCompletesAfterUploadPhaseDetach() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .ready))]
        mock.suspendUploads = true
        let uploadStarted = expectation(description: "upload started")
        mock.onUploadManual = { uploadStarted.fulfill() }
        let completed = expectation(description: "detached completion")
        let viewModel = makeViewModel(mock: mock)
        viewModel.onProcessingComplete = { _ in completed.fulfill() }

        submitManualSource(viewModel)
        await fulfillment(of: [uploadStarted], timeout: 1)

        viewModel.handle(.showAddForm)
        XCTAssertFalse(viewModel.state.isProcessing)
        XCTAssertTrue(viewModel.state.isAddingNewSource)

        mock.resumeUploads()
        await fulfillment(of: [completed], timeout: 1)
    }

    func testDetachedUploadFailureReportsThroughCallback() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [.failure(URLError(.notConnectedToInternet))]
        mock.suspendUploads = true
        let uploadStarted = expectation(description: "upload started")
        mock.onUploadManual = { uploadStarted.fulfill() }
        let failed = expectation(description: "detached failure")
        var reportedMessage: String?
        let viewModel = makeViewModel(mock: mock)
        viewModel.onSourceOperationFailed = { message in
            reportedMessage = message
            failed.fulfill()
        }

        submitManualSource(viewModel)
        await fulfillment(of: [uploadStarted], timeout: 1)

        viewModel.handle(.showAddForm)
        mock.resumeUploads()
        await fulfillment(of: [failed], timeout: 1)

        XCTAssertNotNil(reportedMessage)
    }

    func testDeleteForNewSourceIsNotDroppedWhileAnotherDeleteInFlight() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [
            .success(makeSource(id: "s1", state: .added)),
            .success(makeSource(id: "s2", state: .added))
        ]
        mock.suspendDeletes = true
        let firstStream = expectation(description: "s1 stream")
        let secondStream = expectation(description: "s2 stream")
        var streamCount = 0
        mock.onStatusStream = {
            streamCount += 1
            if streamCount == 1 { firstStream.fulfill() }
            if streamCount == 2 { secondStream.fulfill() }
        }

        let viewModel = makeViewModel(mock: mock)
        submitManualSource(viewModel)
        await fulfillment(of: [firstStream], timeout: 1)
        viewModel.handle(.cancelProcessingTapped)
        viewModel.handle(.confirmCancelProcessing)
        await waitUntil { mock.deletedIDs == ["s1"] }

        viewModel.handle(.showAddForm)
        submitManualSource(viewModel)
        await fulfillment(of: [secondStream], timeout: 1)
        viewModel.handle(.cancelProcessingTapped)
        viewModel.handle(.confirmCancelProcessing)
        await waitUntil { mock.deletedIDs.count == 2 }

        XCTAssertEqual(Set(mock.deletedIDs), ["s1", "s2"])

        mock.resumeDeletes()
        await waitUntil { viewModel.state.isAddingNewSource }
    }

    func testDetachedStreamEndWithoutTerminalRefreshesList() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .added))]
        let (stream, continuation) = AsyncThrowingStream<SourceStatusEvent, Error>.makeStream()
        mock.statusStreams = [stream]
        let streamStarted = expectation(description: "stream started")
        mock.onStatusStream = { streamStarted.fulfill() }
        let refreshed = expectation(description: "list refreshed")
        var refreshedID: String?
        let viewModel = makeViewModel(mock: mock)
        viewModel.onProcessingComplete = {
            refreshedID = $0.id
            refreshed.fulfill()
        }

        submitManualSource(viewModel)
        await fulfillment(of: [streamStarted], timeout: 1)
        viewModel.handle(.showAddForm)
        continuation.finish()

        await fulfillment(of: [refreshed], timeout: 1)
        XCTAssertEqual(refreshedID, "s1")
    }

    func testDetachedRetryFailureReportsThroughCallback() async {
        let mock = MockUploadSourceUseCase()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .failed))]
        mock.retryResults = [.failure(URLError(.timedOut))]
        mock.suspendRetries = true
        let viewModel = makeViewModel(mock: mock)
        submitManualSource(viewModel)
        await waitUntil { viewModel.state.isProcessingFailed }

        let retryStarted = expectation(description: "retry started")
        mock.onRetrySource = { retryStarted.fulfill() }
        let failed = expectation(description: "retry failure")
        viewModel.onSourceOperationFailed = { _ in failed.fulfill() }
        viewModel.handle(.retryProcessing)
        await fulfillment(of: [retryStarted], timeout: 1)

        viewModel.handle(.showAddForm)
        mock.resumeRetries()
        await fulfillment(of: [failed], timeout: 1)
    }

    func testRetryReusesActiveSessionAndStartsProcessing() async {
        let mock = MockUploadSourceUseCase()
        let (retryStream, retryContinuation) = AsyncThrowingStream<SourceStatusEvent, Error>.makeStream()
        mock.uploadResults = [.success(makeSource(id: "s1", state: .failed))]
        mock.retryResults = [.success(makeSource(id: "s1", state: .added))]
        mock.statusStreams = [retryStream]

        let viewModel = makeViewModel(mock: mock)
        submitManualSource(viewModel)
        await waitUntil { viewModel.state.isProcessingFailed }

        let retried = expectation(description: "retried")
        let streamStarted = expectation(description: "status stream started")
        mock.onRetrySource = { retried.fulfill() }
        mock.onStatusStream = { streamStarted.fulfill() }
        viewModel.handle(.retryProcessing)
        await fulfillment(of: [retried, streamStarted], timeout: 1)

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

    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline {
                XCTFail("Timed out waiting for condition", file: file, line: line)
                return
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
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
    var suspendUploads = false
    var suspendRetries = false
    var deleteError: Error?
    var onUploadManual: (() -> Void)?
    var onDelete: (() -> Void)?
    var onRetrySource: (() -> Void)?
    var onStatusStream: (() -> Void)?
    private var deleteContinuations: [CheckedContinuation<Void, Never>] = []
    private var uploadContinuations: [CheckedContinuation<Void, Never>] = []
    private var retryContinuations: [CheckedContinuation<Void, Never>] = []

    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source {
        throw CancellationError()
    }

    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source {
        throw CancellationError()
    }

    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source {
        onUploadManual?()
        guard !uploadResults.isEmpty else { throw CancellationError() }
        let result = uploadResults.removeFirst()
        if suspendUploads {
            await withCheckedContinuation { uploadContinuations.append($0) }
        }
        return try result.get()
    }

    func deleteSource(id: String) async throws {
        deletedIDs.append(id)
        onDelete?()
        if suspendDeletes {
            await withCheckedContinuation { deleteContinuations.append($0) }
        }
        if let deleteError { throw deleteError }
    }

    func retrySource(id: String) async throws -> Source {
        retryCount += 1
        onRetrySource?()
        guard !retryResults.isEmpty else { throw CancellationError() }
        let result = retryResults.removeFirst()
        if suspendRetries {
            await withCheckedContinuation { retryContinuations.append($0) }
        }
        return try result.get()
    }

    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> {
        onStatusStream?()
        guard !statusStreams.isEmpty else { return AsyncThrowingStream { $0.finish() } }
        return statusStreams.removeFirst()
    }

    func resumeDeletes() {
        deleteContinuations.forEach { $0.resume() }
        deleteContinuations.removeAll()
    }

    func resumeUploads() {
        uploadContinuations.forEach { $0.resume() }
        uploadContinuations.removeAll()
    }

    func resumeRetries() {
        retryContinuations.forEach { $0.resume() }
        retryContinuations.removeAll()
    }
}
