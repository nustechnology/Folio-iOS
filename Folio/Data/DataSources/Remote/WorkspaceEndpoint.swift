import Foundation

enum WorkspaceEndpoint: APIEndpoint {
    case list(query: WorkspaceListQuery)
    case create(name: String, objective: String)
    case update(id: String, name: String, objective: String)
    case delete(id: String)

    var path: String {
        switch self {
        case .list: return "/api/v1/spaces"
        case .create: return "/api/v1/spaces"
        case .update(let id, _, _), .delete(let id): return "/api/v1/spaces/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list: return .get
        case .create: return .post
        case .update: return .patch
        case .delete: return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        guard case .list(let query) = self else { return nil }
        return [
            query.sort.map { URLQueryItem(name: "sort", value: $0.rawValue) },
            query.search.flatMap { $0.isEmpty ? nil : URLQueryItem(name: "search", value: $0) },
            query.page.map { URLQueryItem(name: "page", value: String($0)) },
            query.limit.map { URLQueryItem(name: "limit", value: String($0)) }
        ].compactMap { $0 }
    }

    var body: Data? {
        let encoder = JSONEncoder()
        switch self {
        case .create(let name, let objective):
            return try? encoder.encode(WorkspaceMutationDTO(name: name, researchObjective: objective))
        case .update(_, let name, let objective):
            return try? encoder.encode(WorkspaceMutationDTO(name: name, researchObjective: objective))
        case .list, .delete:
            return nil
        }
    }

    var requiresAuthentication: Bool { true }

    var cachePolicy: URLRequest.CachePolicy {
        if case .list = self { return .reloadRevalidatingCacheData }
        return .useProtocolCachePolicy
    }
}

private struct WorkspaceMutationDTO: Encodable {
    let name: String
    let researchObjective: String
}
