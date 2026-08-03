import Foundation

enum WorkspaceEndpoint: APIEndpoint {
    case list
    case create(name: String, objective: String)
    case update(id: String, name: String, objective: String)
    case delete(id: String)

    var path: String {
        switch self {
        case .list, .create: return "/api/v1/workspaces"
        case .update(let id, _, _), .delete(let id): return "/api/v1/workspaces/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list: return .get
        case .create: return .post
        case .update: return .put
        case .delete: return .delete
        }
    }

    var queryItems: [URLQueryItem]? { nil }

    var body: Data? {
        let encoder = JSONEncoder()
        switch self {
        case .create(let name, let objective):
            return try? encoder.encode(WorkspaceMutationDTO(name: name, objective: objective))
        case .update(_, let name, let objective):
            return try? encoder.encode(WorkspaceMutationDTO(name: name, objective: objective))
        case .list, .delete:
            return nil
        }
    }

    var requiresAuthentication: Bool { true }
}

private struct WorkspaceMutationDTO: Encodable {
    let name: String
    let objective: String
}
