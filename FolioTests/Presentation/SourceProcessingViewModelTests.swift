import XCTest
@testable import Folio

@MainActor
final class SourceProcessingViewModelTests: XCTestCase {

    func testBackInvokesCallback() {
        let source = makeSource(state: .added)
        var backCalled = false
        let viewModel = SourceProcessingViewModel(
            source: source,
            uploadSourceUseCase: StubUploadSourceUseCase(),
            onBack: { backCalled = true },
            onDeleted: { _ in },
            onStatusChanged: { _ in }
        )

        viewModel.send(.back)

        XCTAssertTrue(backCalled)
    }

    func testFailedSourceStartsInFailedState() {
        let source = makeSource(state: .failed, error: "Something broke")
        let viewModel = SourceProcessingViewModel(
            source: source,
            uploadSourceUseCase: StubUploadSourceUseCase(),
            onBack: {},
            onDeleted: { _ in },
            onStatusChanged: { _ in }
        )

        XCTAssertTrue(viewModel.state.isProcessingFailed)
        XCTAssertEqual(viewModel.state.errorMessage, "Something broke")
    }

    func testExtractingTextSourceSeedsStageOneActive() {
        let source = makeSource(state: .extractingText)
        let viewModel = SourceProcessingViewModel(
            source: source,
            uploadSourceUseCase: StubUploadSourceUseCase(),
            onBack: {},
            onDeleted: { _ in },
            onStatusChanged: { _ in }
        )

        let statuses = viewModel.state.processingStages.map(\.status)
        XCTAssertEqual(statuses[0], .completed)
        XCTAssertEqual(statuses[1], .active)
        XCTAssertEqual(statuses[2], .pending)
        XCTAssertGreaterThan(viewModel.state.processingProgress, 0)
    }

    func testIndexingEvidenceSourceSeedsStageTwoActive() {
        let source = makeSource(state: .indexingEvidence)
        let viewModel = SourceProcessingViewModel(
            source: source,
            uploadSourceUseCase: StubUploadSourceUseCase(),
            onBack: {},
            onDeleted: { _ in },
            onStatusChanged: { _ in }
        )

        let statuses = viewModel.state.processingStages.map(\.status)
        XCTAssertEqual(statuses[0], .completed)
        XCTAssertEqual(statuses[1], .completed)
        XCTAssertEqual(statuses[2], .active)
    }

    func testRetryCallsRetryUseCase() async {
        let source = makeSource(state: .failed, error: "Something broke")
        let upload = RecordingRetryUploadSourceUseCase()
        let viewModel = SourceProcessingViewModel(
            source: source,
            uploadSourceUseCase: upload,
            onBack: {},
            onDeleted: { _ in },
            onStatusChanged: { _ in }
        )

        viewModel.send(.retry)
        await waitForTasks()

        XCTAssertEqual(upload.retryCount, 1)
    }

    func testDeleteConfirmedCallsDeleteAndCallback() async {
        let source = makeSource(state: .failed, error: "Something broke")
        let upload = RecordingDeleteUploadSourceUseCase()
        var deletedSource: Source?
        let viewModel = SourceProcessingViewModel(
            source: source,
            uploadSourceUseCase: upload,
            onBack: {},
            onDeleted: { deletedSource = $0 },
            onStatusChanged: { _ in }
        )

        viewModel.send(.deleteTapped)
        XCTAssertTrue(viewModel.state.showDeleteConfirmation)

        viewModel.send(.deleteConfirmed)
        await waitForTasks()

        XCTAssertEqual(upload.deletedIDs, [source.id])
        XCTAssertEqual(deletedSource?.id, source.id)
        XCTAssertTrue(viewModel.state.shouldDismiss)
    }

    private func makeSource(state: SourceProcessingState, error: String = "") -> Source {
        Source(
            id: "proc",
            researchSpaceId: "space-1",
            sourceType: .web,
            title: "Source",
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
            processingError: error,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func waitForTasks() async {
        await Task.yield()
        await Task.yield()
    }
}

private struct StubUploadSourceUseCase: UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func deleteSource(id: String) async throws {}
    func retrySource(id: String) async throws -> Source { throw CancellationError() }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> { AsyncThrowingStream { $0.finish() } }
}

@MainActor
private final class RecordingRetryUploadSourceUseCase: UploadSourceUseCaseProtocol {
    private(set) var retryCount = 0

    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func deleteSource(id: String) async throws {}
    func retrySource(id: String) async throws -> Source {
        retryCount += 1
        return makeSource(id: id, state: .added)
    }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> { AsyncThrowingStream { $0.finish() } }

    private func makeSource(id: String, state: SourceProcessingState) -> Source {
        Source(
            id: id,
            researchSpaceId: "space-1",
            sourceType: .web,
            title: "Source",
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
}

@MainActor
private final class RecordingDeleteUploadSourceUseCase: UploadSourceUseCaseProtocol {
    private(set) var deletedIDs: [String] = []

    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func deleteSource(id: String) async throws {
        deletedIDs.append(id)
    }
    func retrySource(id: String) async throws -> Source { throw CancellationError() }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> { AsyncThrowingStream { $0.finish() } }
}
