import Foundation

fileprivate func noteDetailPath(spaceId: String, noteId: String) -> String {
  "/api/v1/spaces/\(spaceId)/notes/\(noteId)"
}

struct NoteListEndpoint: APIEndpoint {
  let query: NoteListQuery
  var path: String { "/api/v1/spaces/\(query.spaceId)/notes" }
  var method: HTTPMethod { .get }
  var requiresAuthentication: Bool { true }
  var body: Data? { nil }
  var cachePolicy: URLRequest.CachePolicy { .reloadRevalidatingCacheData }
  var queryItems: [URLQueryItem]? {
    var items: [URLQueryItem] = []
    if let search = query.search, !search.isEmpty {
      items.append(URLQueryItem(name: "search", value: search))
    }
    items.append(URLQueryItem(name: "sort", value: query.sort))
    items.append(URLQueryItem(name: "origin", value: query.origin))
    if let page = query.page { items.append(URLQueryItem(name: "page", value: String(page))) }
    if let limit = query.limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
    return items
  }
}

struct NoteDetailEndpoint: APIEndpoint {
  let spaceId: String
  let noteId: String
  var path: String { noteDetailPath(spaceId: spaceId, noteId: noteId) }
  var method: HTTPMethod { .get }
  var queryItems: [URLQueryItem]? { nil }
  var body: Data? { nil }
  var requiresAuthentication: Bool { true }
}

struct CreateNoteEndpoint: APIEndpoint {
  let spaceId: String
  let request: CreateNoteRequestDTO

  var path: String { "/api/v1/spaces/\(spaceId)/notes" }
  var method: HTTPMethod { .post }
  var queryItems: [URLQueryItem]? { nil }
  var requiresAuthentication: Bool { true }
  var body: Data? {
    let data = try? JSONEncoder().encode(request)
    if let data, let json = String(data: data, encoding: .utf8) {
      Logger.debug("CreateNoteEndpoint payload: \(json)")
    }
    return data
  }

  init(spaceId: String, title: String, content: String) {
    self.spaceId = spaceId
    self.request = CreateNoteRequestDTO(title: title, content: content)
  }

  init(spaceId: String, request: CreateNoteRequestDTO) {
    self.spaceId = spaceId
    self.request = request
  }
}

struct ConvertNoteToSourceEndpoint: APIEndpoint {
  let spaceId: String
  let noteId: String
  let title: String

  var path: String { "\(noteDetailPath(spaceId: spaceId, noteId: noteId))/convert-to-source" }
  var method: HTTPMethod { .post }
  var queryItems: [URLQueryItem]? { nil }
  var requiresAuthentication: Bool { true }
  var body: Data? {
    try? JSONEncoder().encode(ConvertNoteRequestDTO(title: title))
  }
}

struct UpdateNoteEndpoint: APIEndpoint {
  let spaceId: String
  let noteId: String
  let title: String
  let content: String
  var path: String { noteDetailPath(spaceId: spaceId, noteId: noteId) }
  var method: HTTPMethod { .patch }
  var queryItems: [URLQueryItem]? { nil }
  var requiresAuthentication: Bool { true }
  var body: Data? {
    try? JSONEncoder().encode(UpdateNoteRequestDTO(title: title, content: content))
  }
}

struct DeleteNoteEndpoint: APIEndpoint {
  let spaceId: String
  let noteId: String
  var path: String { noteDetailPath(spaceId: spaceId, noteId: noteId) }
  var method: HTTPMethod { .delete }
  var queryItems: [URLQueryItem]? { nil }
  var body: Data? { nil }
  var requiresAuthentication: Bool { true }
}
