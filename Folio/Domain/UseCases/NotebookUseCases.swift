import Foundation

struct NotebookFetchResult {
    let entry: NotebookEntry
    let preservedOfflineDraft: Bool
}

protocol FetchNotebookUseCaseProtocol {
    func execute(spaceId: String) async throws -> NotebookFetchResult
}

final class FetchNotebookUseCase: FetchNotebookUseCaseProtocol {
    private let repository: NotebookRepositoryProtocol

    init(repository: NotebookRepositoryProtocol) { self.repository = repository }

    func execute(spaceId: String) async throws -> NotebookFetchResult {
        try await repository.fetchNotebook(spaceId: spaceId)
    }
}

protocol SaveNotebookUseCaseProtocol {
    func execute(entry: NotebookEntry) async throws
}

final class SaveNotebookUseCase: SaveNotebookUseCaseProtocol {
    private let repository: NotebookRepositoryProtocol

    init(repository: NotebookRepositoryProtocol) { self.repository = repository }

    func execute(entry: NotebookEntry) async throws {
        try await repository.saveNotebook(entry: entry)
    }
}
