import Foundation

protocol FetchSourceDetailUseCaseProtocol {
    func execute(id: String) async throws -> Source
}

final class FetchSourceDetailUseCase: FetchSourceDetailUseCaseProtocol {
    private let repository: SourceRepositoryProtocol

    init(repository: SourceRepositoryProtocol) {
        self.repository = repository
    }

    func execute(id: String) async throws -> Source {
        try await repository.fetchSource(id: id)
    }
}
