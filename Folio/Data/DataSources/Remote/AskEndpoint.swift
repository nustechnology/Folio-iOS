import Foundation

struct AskSuggestionsEndpoint: APIEndpoint {
  let spaceId: String
  let scope: String
  let sourceId: String?
  var path: String { "/api/v1/spaces/\(spaceId)/ask/suggestions" }
  var method: HTTPMethod { .get }
  var queryItems: [URLQueryItem]? {
    var items = [URLQueryItem(name: "scope", value: scope)]
    if let sourceId { items.append(URLQueryItem(name: "sourceId", value: sourceId)) }
    return items
  }
  var body: Data? { nil }
  var requiresAuthentication: Bool { true }
}

struct AskConversationListEndpoint: APIEndpoint {
  let query: AskConversationListQuery
  var path: String { "/api/v1/spaces/\(query.spaceId)/conversations" }
  var method: HTTPMethod { .get }
  var requiresAuthentication: Bool { true }
  var body: Data? { nil }
  var queryItems: [URLQueryItem]? {
    var items: [URLQueryItem] = []
    if let page = query.page { items.append(URLQueryItem(name: "page", value: String(page))) }
    if let limit = query.limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
    if let search = query.search, !search.isEmpty { items.append(URLQueryItem(name: "search", value: search)) }
    return items
  }
}

struct AskConversationDetailEndpoint: APIEndpoint {
  let spaceId: String
  let conversationId: String
  var path: String { "/api/v1/spaces/\(spaceId)/conversations/\(conversationId)" }
  var method: HTTPMethod { .get }
  var requiresAuthentication: Bool { true }
  var body: Data? { nil }
  var queryItems: [URLQueryItem]? { nil }
}

struct AskFeedbackRequestDTO: Encodable {
  let rating: String
}

struct AskFeedbackEndpoint: APIEndpoint {
  let spaceId: String
  let conversationId: String
  let messageId: String
  let rating: String
  var path: String { "/api/v1/spaces/\(spaceId)/conversations/\(conversationId)/messages/\(messageId)/feedback" }
  var method: HTTPMethod { .post }
  var requiresAuthentication: Bool { true }
  var body: Data? { try? JSONEncoder().encode(AskFeedbackRequestDTO(rating: rating)) }
  var queryItems: [URLQueryItem]? { nil }
}

struct DeleteConversationEndpoint: APIEndpoint {
  let spaceId: String
  let conversationId: String
  var path: String { "/api/v1/spaces/\(spaceId)/conversations/\(conversationId)" }
  var method: HTTPMethod { .delete }
  var requiresAuthentication: Bool { true }
  var body: Data? { nil }
  var queryItems: [URLQueryItem]? { nil }
}

struct RenameConversationRequestDTO: Encodable {
  let title: String
}

struct RenameConversationEndpoint: APIEndpoint {
  let spaceId: String
  let conversationId: String
  let title: String
  var path: String { "/api/v1/spaces/\(spaceId)/conversations/\(conversationId)" }
  var method: HTTPMethod { .patch }
  var requiresAuthentication: Bool { true }
  var body: Data? { try? JSONEncoder().encode(RenameConversationRequestDTO(title: title)) }
  var queryItems: [URLQueryItem]? { nil }
}

struct AskStreamAnswerEndpoint {
  let url: URL
  let accessToken: String?
  let body: Data

  init(url: URL, accessToken: String?, body: Data) {
    self.url = url
    self.accessToken = accessToken
    self.body = body
  }

  init(
    baseURL: URL,
    spaceId: String,
    question: String,
    scope: String,
    sourceId: String?,
    conversationId: String?,
    accessToken: String?
  ) throws {
    self.url = baseURL.appendingPathComponent("/api/v1/spaces/\(spaceId)/ask")
    self.accessToken = accessToken
    let requestBody = AskQuestionRequestDTO(
      question: question, scope: scope, sourceId: sourceId, conversationId: conversationId)
    let encoder = JSONEncoder()
    self.body = try encoder.encode(requestBody)
  }

  var urlRequest: URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = HTTPMethod.post.rawValue
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.cachePolicy = .reloadIgnoringLocalCacheData
    if let accessToken, !accessToken.isEmpty {
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    return request
  }
}
