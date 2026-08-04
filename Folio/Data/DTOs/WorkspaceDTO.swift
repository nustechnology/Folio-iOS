import Foundation

struct WorkspaceDTO: Codable {
    let id: String
    let name: String
    let objective: String
    let sourceCount: Int
    let noteCount: Int
    let updatedAt: Date

    func toDomain() -> Workspace {
        Workspace(id: id, name: name, objective: objective, sourceCount: sourceCount, noteCount: noteCount, updatedAt: updatedAt)
    }
}

struct SpaceDTO: Codable {
    let id: String
    let name: String
    let researchObjective: String
    let sourceCount: Int
    let noteCount: Int
    let updatedAt: Date

    func toDomain() -> Workspace {
        Workspace(
            id: id,
            name: name,
            objective: researchObjective,
            sourceCount: sourceCount,
            noteCount: noteCount,
            updatedAt: updatedAt
        )
    }
}

struct PaginationDTO: Codable {
    let page: Int
    let limit: Int
    let totalCount: Int
    let totalPages: Int
}

struct WorkspaceResponseDataDTO: Codable {
    let spaces: [SpaceDTO]
    let pagination: PaginationDTO?
}

struct WorkspaceResponseDTO: Codable {
    let status: String
    let data: WorkspaceResponseDataDTO

    func toDomain() -> WorkspaceListResult {
        WorkspaceListResult(
            workspaces: data.spaces.map { $0.toDomain() },
            pagination: data.pagination.map {
                WorkspacePagination(
                    page: $0.page,
                    limit: $0.limit,
                    totalCount: $0.totalCount,
                    totalPages: $0.totalPages
                )
            }
        )
    }
}

struct CreateSpaceResponseDTO: Codable {
    let status: String
    let data: CreateSpaceDataDTO

    struct CreateSpaceDataDTO: Codable {
        let space: SpaceDTO
    }
}
