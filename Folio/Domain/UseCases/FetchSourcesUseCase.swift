import Foundation

protocol FetchSourcesUseCaseProtocol {
    func execute(query: SourceListQuery) async throws -> SourceListResult
}

final class FetchSourcesUseCase: FetchSourcesUseCaseProtocol {
    private let repository: SourceRepositoryProtocol

    init(repository: SourceRepositoryProtocol) {
        self.repository = repository
    }

    func execute(query: SourceListQuery) async throws -> SourceListResult {
        try await repository.fetchSources(query: query)
    }
}
