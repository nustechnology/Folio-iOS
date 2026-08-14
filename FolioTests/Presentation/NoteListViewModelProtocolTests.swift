@testable import Folio
import XCTest

@MainActor
final class NoteListViewModelProtocolTests: XCTestCase {
    func testConformsToViewModelProtocol() {
        let viewModel = NoteListViewModel(
            spaceId: "space-1",
            fetchNotesUseCase: EmptyNotesUseCase(),
            fetchNoteUseCase: UnusedNoteUseCase(),
            updateNoteUseCase: UnusedUpdateNoteUseCase(),
            deleteNoteUseCase: UnusedDeleteNoteUseCase()
        )

        acceptViewModel(viewModel)
    }

    private func acceptViewModel<ViewModel: ViewModelProtocol>(_ viewModel: ViewModel) {}
}

private struct EmptyNotesUseCase: FetchNotesUseCaseProtocol {
    func execute(query: NoteListQuery) async throws -> NoteListResult {
        NoteListResult(notes: [], pagination: nil)
    }
}

private struct UnusedNoteUseCase: FetchNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String) async throws -> Note {
        fatalError("Unused")
    }
}

private struct UnusedUpdateNoteUseCase: UpdateNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String, title: String, content: String) async throws -> Note {
        fatalError("Unused")
    }
}

private struct UnusedDeleteNoteUseCase: DeleteNoteUseCaseProtocol {
    func execute(spaceId: String, noteId: String) async throws {}
}
