import Foundation

protocol SourceRepositoryProtocol {
    func fetchSources(query: SourceListQuery) async throws -> SourceListResult
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source
    func updateSource(id: String, title: String, author: String) async throws -> Source
    func deleteSource(id: String) async throws
    func retrySource(id: String) async throws -> Source
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error>
}
