import Foundation

enum AuthEndpoint: APIEndpoint {
    case signUp(name: String, email: String, password: String, confirmPassword: String)
    case signIn(email: String, password: String)
    case refreshToken(refreshToken: String)

    var path: String {
        switch self {
        case .signUp:
            return "/api/v1/auth/sign-up"
        case .signIn:
            return "/api/v1/auth/login"
        case .refreshToken:
            return "/api/v1/auth/refresh"
        }
    }

    var method: HTTPMethod {
        .post
    }

    var queryItems: [URLQueryItem]? { nil }

    var body: Data? {
        let encoder = JSONEncoder()
        switch self {
        case .signUp(let name, let email, let password, let confirmPassword):
            return try? encoder.encode(SignUpRequest(name: name, email: email, password: password, confirmPassword: confirmPassword))
        case .signIn(let email, let password):
            return try? encoder.encode(SignInRequest(email: email, password: password))
        case .refreshToken(let refreshToken):
            return try? encoder.encode(RefreshRequest(refreshToken: refreshToken))
        }
    }
}

private struct SignUpRequest: Codable {
    let name: String
    let email: String
    let password: String
    let confirmPassword: String
}

private struct SignInRequest: Codable {
    let email: String
    let password: String
}

private struct RefreshRequest: Codable {
    let refreshToken: String
}
