import Foundation

final class RemoteWorkspaceRepository: WorkspaceRepositoryProtocol {
    private let networkService: NetworkServiceProtocol

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }


    func fetchWorkspaces() async throws -> [Workspace] {
         let response: [WorkspaceDTO] = try await networkService.request(WorkspaceEndpoint.list)
         return response.map { $0.toDomain() }
    }
    

    func createWorkspace(name: String, objective: String) async throws -> Workspace {
         return try await requestWorkspace(WorkspaceEndpoint.create(name: name, objective: objective))
    }

    func updateWorkspace(id: String, name: String, objective: String) async throws -> Workspace {
        return try await requestWorkspace(WorkspaceEndpoint.update(id: id, name: name, objective: objective))
    }

    func deleteWorkspace(id: String) async throws {
        try await networkService.requestVoid(WorkspaceEndpoint.delete(id: id))
    }

     private func requestWorkspace(_ endpoint: APIEndpoint) async throws -> Workspace {
         let response: WorkspaceDTO = try await networkService.request(endpoint)
         return response.toDomain()
     }
    
    private static let seed: [Workspace] = [
        Workspace(id: "dissertation-research", name: "Dissertation Research", objective: "Primary research archive for doctoral thesis", sourceCount: 128, noteCount: 32, updatedAt: Date().addingTimeInterval(-2 * 86_400)),
        Workspace(id: "public-policy-insights", name: "Public Policy Insights", objective: "Policy papers and legislative analysis", sourceCount: 64, noteCount: 18, updatedAt: Date().addingTimeInterval(-5 * 3_600)),
        Workspace(id: "history-of-science", name: "History of Science", objective: "Scientific manuscripts and archival sources", sourceCount: 42, noteCount: 12, updatedAt: Date().addingTimeInterval(-7 * 86_400)),
        Workspace(id: "teaching-prep", name: "Teaching Prep", objective: "Course materials and lecture notes", sourceCount: 27, noteCount: 8, updatedAt: Date().addingTimeInterval(-3 * 86_400))
    ]
}
