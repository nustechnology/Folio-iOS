import Foundation

protocol NetworkServiceProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
    func requestVoid(_ endpoint: APIEndpoint) async throws
}

protocol APIEndpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
    var headers: [String: String]? { get }
    var requiresAuthentication: Bool { get }
    var contentType: String { get }
    var resiliencePolicy: EndpointResiliencePolicy { get }
}

extension APIEndpoint {
    var headers: [String: String]? { nil }
    var requiresAuthentication: Bool { false }
    var contentType: String { "application/json" }
    var resiliencePolicy: EndpointResiliencePolicy {
        method == .get ? .read : .nonRetryable
    }
}

struct EndpointResiliencePolicy: Equatable {
    let requestTimeout: TimeInterval
    let resourceTimeout: TimeInterval
    let maximumAttempts: Int
    let isRetryable: Bool
    let baseBackoff: TimeInterval
    let maximumBackoff: TimeInterval
    let maximumRetryAfter: TimeInterval
    let jitterFraction: Double

    static let read = EndpointResiliencePolicy(
        requestTimeout: 15,
        resourceTimeout: 120,
        maximumAttempts: 3,
        isRetryable: true,
        baseBackoff: 0.25,
        maximumBackoff: 4,
        maximumRetryAfter: 30,
        jitterFraction: 1
    )

    static let nonRetryable = EndpointResiliencePolicy(
        requestTimeout: 15,
        resourceTimeout: 120,
        maximumAttempts: 1,
        isRetryable: false,
        baseBackoff: 0,
        maximumBackoff: 0,
        maximumRetryAfter: 0,
        jitterFraction: 0
    )

    static let upload = EndpointResiliencePolicy(
        requestTimeout: 15,
        resourceTimeout: 300,
        maximumAttempts: 1,
        isRetryable: false,
        baseBackoff: 0,
        maximumBackoff: 0,
        maximumRetryAfter: 0,
        jitterFraction: 0
    )
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}
