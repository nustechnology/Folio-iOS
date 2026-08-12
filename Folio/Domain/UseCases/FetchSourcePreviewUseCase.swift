import Foundation

protocol FetchSourcePreviewUseCaseProtocol {
    func execute(source: Source) async throws -> SourcePreview
}

final class FetchSourcePreviewUseCase: FetchSourcePreviewUseCaseProtocol {
    private let repository: SourceRepositoryProtocol

    init(repository: SourceRepositoryProtocol) {
        self.repository = repository
    }

    func execute(source: Source) async throws -> SourcePreview {
        if source.sourceType == .web, let url = URL(string: source.sourceUrl),
           let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return SourcePreview(url: url.absoluteString)
        }
        return try await repository.fetchSourcePreview(id: source.id)
    }
}
