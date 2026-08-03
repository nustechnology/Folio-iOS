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
