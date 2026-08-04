import Foundation

struct SourceStatusEndpoint {
    let url: URL
    let accessToken: String?

    init(baseURL: URL, accessToken: String?) {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/sources/status"), resolvingAgainstBaseURL: true)
        self.url = components?.url ?? baseURL
        self.accessToken = accessToken
    }

    var urlRequest: URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let token = accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
