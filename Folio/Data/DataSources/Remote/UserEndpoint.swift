import Foundation

enum UserEndpoint: APIEndpoint {
    case getUsers
    case getMe

    var path: String {
        switch self {
        case .getUsers:
            return "/users"
        case .getMe:
            return "/api/v1/users/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getUsers, .getMe:
            return .get
        }
    }

    var requiresAuthentication: Bool {
        switch self {
        case .getUsers:
            return false
        case .getMe:
            return true
        }
    }

    var queryItems: [URLQueryItem]? { nil }
    var body: Data? { nil }
}
