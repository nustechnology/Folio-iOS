import Foundation

final class SourceRepository: SourceRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    private let baseURL: URL
    private let accessTokenProvider: AccessTokenProvider?

    init(
        networkService: NetworkServiceProtocol,
        baseURL: URL,
        accessTokenProvider: AccessTokenProvider? = nil
    ) {
        self.networkService = networkService
        self.baseURL = baseURL
        self.accessTokenProvider = accessTokenProvider
    }

    func fetchSources(query: SourceListQuery) async throws -> SourceListResult {
        let response: SourceListResponseDTO = try await networkService.request(SourceListEndpoint(query: query))
        return response.toDomain()
    }

    func updateSource(id: String, title: String, author: String) async throws -> Source {
        let response: SourceResponseDTO = try await networkService.request(UpdateSourceEndpoint(sourceId: id, title: title, author: author))
        return response.data.source.toDomain()
    }

    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source {
        let endpoint = try SourceFileUploadEndpoint(spaceId: spaceId, fileURL: fileURL, title: title, author: author)
        let response: SourceResponseDTO = try await networkService.request(endpoint)
        return response.data.source.toDomain()
    }

    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source {
        let endpoint = SourceJSONEndpoint.uploadWeb(spaceId: spaceId, url: url, title: title, author: author)
        let response: SourceResponseDTO = try await networkService.request(endpoint)
        return response.data.source.toDomain()
    }

    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source {
        let endpoint = SourceJSONEndpoint.uploadManual(spaceId: spaceId, content: content, title: title, author: author)
        let response: SourceResponseDTO = try await networkService.request(endpoint)
        return response.data.source.toDomain()
    }

    func deleteSource(id: String) async throws {
        try await networkService.requestVoid(DeleteSourceEndpoint(sourceId: id))
    }

    func retrySource(id: String) async throws -> Source {
        let response: SourceResponseDTO = try await networkService.request(RetrySourceEndpoint(sourceId: id))
        return response.data.source.toDomain()
    }

    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> {
        let endpoint = SourceStatusEndpoint(baseURL: baseURL, accessToken: accessTokenProvider?.accessToken)
        let client = SourceStatusSSEClient()
        return client.connect(endpoint: endpoint)
    }
}
