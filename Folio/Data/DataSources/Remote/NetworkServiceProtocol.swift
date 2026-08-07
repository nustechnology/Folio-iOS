import Foundation

protocol NetworkServiceProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
    func requestVoid(_ endpoint: APIEndpoint) async throws
    func cancelPendingRefresh()
    func cancelPendingRefreshAndWait() async
}

extension NetworkServiceProtocol {
    func cancelPendingRefresh() {}
    func cancelPendingRefreshAndWait() async { cancelPendingRefresh() }
}

protocol APIEndpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
    var headers: [String: String]? { get }
    var requiresAuthentication: Bool { get }
    var contentType: String { get }
    var cachePolicy: URLRequest.CachePolicy { get }
    var allowsAutomaticRetry: Bool { get }
}

extension APIEndpoint {
    var headers: [String: String]? { nil }
    var requiresAuthentication: Bool { false }
    var contentType: String { "application/json" }
    var cachePolicy: URLRequest.CachePolicy { .useProtocolCachePolicy }
    var allowsAutomaticRetry: Bool { method == .get }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}
