import Foundation

enum UserEndpoint: APIEndpoint {
    case getUsers

    var path: String {
        switch self {
        case .getUsers:
            return "/users"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getUsers:
            return .get
        }
    }

    var queryItems: [URLQueryItem]? { nil }
    var body: Data? { nil }
}
