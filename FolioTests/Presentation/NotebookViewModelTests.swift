import XCTest
@testable import Folio

@MainActor
final class NotebookViewModelTests: XCTestCase {
    func testUndoRestoresTypingAttributesAfterCaretFormatting() {
        let viewModel = NotebookViewModel(
            fetchNotebookUseCase: StubFetchNotebookUseCase(),
            saveNotebookUseCase: StubSaveNotebookUseCase()
        )
        viewModel.attributedText = NSAttributedString(string: "text")
        viewModel.selectedRange = NSRange(location: 4, length: 0)

        viewModel.handle(.bold)
        XCTAssertTrue(viewModel.typingAttributes[.font] is UIFont)

        viewModel.handle(.undo)

        XCTAssertTrue(viewModel.typingAttributes.isEmpty)
        XCTAssertEqual(viewModel.selectedRange, NSRange(location: 4, length: 0))
    }

    func testFormattingEmptyNotebookDoesNotSaveUnchangedContent() async {
        let saveUseCase = RecordingSaveNotebookUseCase()
        let viewModel = NotebookViewModel(
            fetchNotebookUseCase: StubFetchNotebookUseCase(),
            saveNotebookUseCase: saveUseCase
        )

        viewModel.handle(.bold)
        viewModel.flushPendingSave()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(saveUseCase.callCount, 0)
    }
}

private struct StubFetchNotebookUseCase: FetchNotebookUseCaseProtocol {
    func execute(spaceId: String) async throws -> NotebookFetchResult {
        NotebookFetchResult(
            entry: NotebookEntry(id: "", researchSpaceId: spaceId, content: "", createdAt: .now, updatedAt: .now),
            preservedOfflineDraft: false
        )
    }
}

private struct StubSaveNotebookUseCase: SaveNotebookUseCaseProtocol {
    func execute(entry: NotebookEntry) async throws {}
}

private final class RecordingSaveNotebookUseCase: SaveNotebookUseCaseProtocol, @unchecked Sendable {
    var callCount = 0

    func execute(entry: NotebookEntry) async throws {
        callCount += 1
    }
}
