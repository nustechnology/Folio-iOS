import Foundation

protocol WorkspaceRepositoryProtocol: AnyObject {
    func fetchWorkspaces(query: WorkspaceListQuery) async throws -> WorkspaceListResult
    func createWorkspace(name: String, objective: String) async throws -> Workspace
    func updateWorkspace(id: String, name: String, objective: String) async throws -> Workspace
    func deleteWorkspace(id: String) async throws
}
