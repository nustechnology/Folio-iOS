import Foundation

protocol UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source
    func deleteSource(id: String) async throws
    func retrySource(id: String) async throws -> Source
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error>
}

final class UploadSourceUseCase: UploadSourceUseCaseProtocol {
    private let repository: SourceRepositoryProtocol

    init(repository: SourceRepositoryProtocol) {
        self.repository = repository
    }

    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source {
        try await repository.uploadFile(spaceId: spaceId, fileURL: fileURL, title: title, author: author)
    }

    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source {
        try await repository.uploadWeb(spaceId: spaceId, url: url, title: title, author: author)
    }

    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source {
        try await repository.uploadManual(spaceId: spaceId, content: content, title: title, author: author)
    }

    func deleteSource(id: String) async throws {
        try await repository.deleteSource(id: id)
    }

    func retrySource(id: String) async throws -> Source {
        try await repository.retrySource(id: id)
    }

    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> {
        repository.sourceStatusStream()
    }
}
