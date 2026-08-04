import Foundation

protocol FetchWorkspacesUseCaseProtocol {
    func execute(query: WorkspaceListQuery) async throws -> WorkspaceListResult
}

final class FetchWorkspacesUseCase: FetchWorkspacesUseCaseProtocol {
    private let repository: WorkspaceRepositoryProtocol

    init(repository: WorkspaceRepositoryProtocol) {
        self.repository = repository
    }

    func execute(query: WorkspaceListQuery) async throws -> WorkspaceListResult {
        try await repository.fetchWorkspaces(query: query)
    }
}

protocol CreateWorkspaceUseCaseProtocol {
    func execute(name: String, objective: String) async throws -> Workspace
}

final class CreateWorkspaceUseCase: CreateWorkspaceUseCaseProtocol {
    private let repository: WorkspaceRepositoryProtocol

    init(repository: WorkspaceRepositoryProtocol) { self.repository = repository }

    func execute(name: String, objective: String) async throws -> Workspace {
        try await repository.createWorkspace(name: name, objective: objective)
    }
}

protocol UpdateWorkspaceUseCaseProtocol {
    func execute(id: String, name: String, objective: String) async throws -> Workspace
}

final class UpdateWorkspaceUseCase: UpdateWorkspaceUseCaseProtocol {
    private let repository: WorkspaceRepositoryProtocol

    init(repository: WorkspaceRepositoryProtocol) { self.repository = repository }

    func execute(id: String, name: String, objective: String) async throws -> Workspace {
        try await repository.updateWorkspace(id: id, name: name, objective: objective)
    }
}

protocol DeleteWorkspaceUseCaseProtocol {
    func execute(id: String) async throws
}

final class DeleteWorkspaceUseCase: DeleteWorkspaceUseCaseProtocol {
    private let repository: WorkspaceRepositoryProtocol

    init(repository: WorkspaceRepositoryProtocol) { self.repository = repository }

    func execute(id: String) async throws {
        try await repository.deleteWorkspace(id: id)
    }
}
