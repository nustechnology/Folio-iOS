import Foundation

enum NotebookEndpoint: APIEndpoint {
    case fetch(spaceId: String)
    case save(spaceId: String, content: String)

    var path: String {
        switch self {
        case .fetch(let spaceId), .save(let spaceId, _):
            return "/api/v1/spaces/\(spaceId)/notebook"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .fetch: return .get
        case .save: return .put
        }
    }

    var queryItems: [URLQueryItem]? { nil }

    var body: Data? {
        guard case .save(_, let content) = self else { return nil }
        return try? JSONEncoder().encode(NotebookSaveDTO(content: content))
    }

    var requiresAuthentication: Bool { true }
}
