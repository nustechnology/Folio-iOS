import Foundation

enum NoteLimits {
  static let maximumTitleLength = 150
  static let maximumContentLength = 20_000
}

enum NoteSortOption: String, CaseIterable, Equatable, Hashable, Sendable, SortOptionProtocol {
  case recentlyUpdated = "recently-updated"
  case recentlyCreated = "recently-created"
  case alphabeticalAZ = "alphabetical-az"
  case alphabeticalZA = "alphabetical-za"

  var displayTitle: String {
    switch self {
    case .recentlyUpdated: String(localized: "Recently Updated")
    case .recentlyCreated: String(localized: "Recently Created")
    case .alphabeticalAZ: String(localized: "Alphabetical A-Z")
    case .alphabeticalZA: String(localized: "Alphabetical Z-A")
    }
  }
}

enum NoteOriginType: String, Equatable, Sendable {
  case userCreated = "UserCreated"
  case savedAssistantAnswer = "SavedAssistantAnswer"

  var title: String {
    switch self {
    case .userCreated: return String(localized: "User-created")
    case .savedAssistantAnswer: return String(localized: "Saved answer")
    }
  }
}

struct NoteSummary: Identifiable, Equatable, Sendable {
  let id: String
  let researchSpaceId: String
  let title: String
  let originType: NoteOriginType
  let contentPreview: String
  let createdAt: Date
  let updatedAt: Date
  let citationCount: Int?
}

struct Note: Identifiable, Equatable, Sendable {
  let id: String
  let researchSpaceId: String
  let title: String
  let originType: NoteOriginType
  let content: String
  let createdAt: Date
  let updatedAt: Date
  let citationCount: Int?

  var hasCitations: Bool {
    citationCount ?? 0 > 0
  }

  var summary: NoteSummary {
    NoteSummary(
      id: id, researchSpaceId: researchSpaceId, title: title, originType: originType,
      contentPreview: content, createdAt: createdAt, updatedAt: updatedAt,
      citationCount: citationCount)
  }
}

struct NoteListQuery: Equatable, Sendable {
  let spaceId: String
  let search: String?
  let sort: String
  let origin: String
  let page: Int?
  let limit: Int?

  init(
    spaceId: String, search: String? = nil, sort: String = "recently-updated",
    origin: String = "all", page: Int? = nil, limit: Int? = nil
  ) {
    self.spaceId = spaceId
    self.search = search
    self.sort = sort
    self.origin = origin
    self.page = page
    self.limit = limit
  }
}

struct NotePagination: Equatable, Sendable {
  let page: Int
  let limit: Int
  let totalCount: Int
  let totalPages: Int
}

struct NoteListResult: Equatable, Sendable {
  let notes: [NoteSummary]
  let pagination: NotePagination?
}
