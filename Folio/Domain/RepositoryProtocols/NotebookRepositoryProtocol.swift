import Foundation

protocol NotebookRepositoryProtocol {
    func fetchNotebook(spaceId: String) async throws -> NotebookFetchResult
    func saveNotebook(entry: NotebookEntry) async throws
}
