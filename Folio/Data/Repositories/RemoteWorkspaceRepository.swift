import Foundation

final class RemoteWorkspaceRepository: WorkspaceRepositoryProtocol {
    private let networkService: NetworkServiceProtocol

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func fetchWorkspaces(query: WorkspaceListQuery) async throws -> WorkspaceListResult {
         let response: WorkspaceResponseDTO = try await networkService.request(WorkspaceEndpoint.list(query: query))
         return response.toDomain()
    }


    func createWorkspace(name: String, objective: String) async throws -> Workspace {
         try await performMutation(WorkspaceEndpoint.create(name: name, objective: objective))
    }

    func updateWorkspace(id: String, name: String, objective: String) async throws -> Workspace {
        try await performMutation(WorkspaceEndpoint.update(id: id, name: name, objective: objective))
    }

    func deleteWorkspace(id: String) async throws {
        try await networkService.requestVoid(WorkspaceEndpoint.delete(id: id))
    }

    private func performMutation(_ endpoint: APIEndpoint) async throws -> Workspace {
        do {
            let response: CreateSpaceResponseDTO = try await networkService.request(endpoint)
            return response.data.space.toDomain()
        } catch let error as NetworkError {
            if let data = error.errorData,
               let apiError = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) {
                throw WorkspaceRepositoryError.validation(apiError.message)
            }
            throw WorkspaceRepositoryError.failed(error.localizedDescription)
        }
    }
}
