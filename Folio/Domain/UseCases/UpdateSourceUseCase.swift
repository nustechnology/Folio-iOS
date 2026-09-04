import Foundation

protocol UpdateSourceUseCaseProtocol {
    func execute(id: String, title: String, author: String, content: String?) async throws -> Source
}

final class UpdateSourceUseCase: UpdateSourceUseCaseProtocol {
    private let repository: SourceRepositoryProtocol

    init(repository: SourceRepositoryProtocol) {
        self.repository = repository
    }

    func execute(id: String, title: String, author: String, content: String?) async throws -> Source {
        try await repository.updateSource(id: id, title: title, author: author, content: content)
    }
}
