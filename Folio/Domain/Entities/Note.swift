import Foundation

enum NoteValidationError: Equatable {
  case titleTooLong
  case rawHTMLTooLong
  case contentEmpty
  case contentTooLong

  var localizedMessage: String {
    switch self {
    case .titleTooLong:
      String.localizedStringWithFormat(
        String(localized: "Title cannot exceed %@ characters"),
        NoteLimits.maximumTitleLengthLabel
      )
    case .rawHTMLTooLong:
      String.localizedStringWithFormat(
        String(localized: "Content exceeds maximum length of %@ characters"),
        NoteLimits.maximumRawHTMLLengthLabel
      )
    case .contentEmpty:
      String(localized: "Content cannot be empty")
    case .contentTooLong:
      String.localizedStringWithFormat(
        String(localized: "Content exceeds maximum length of %@ characters"),
        NoteLimits.maximumContentLengthLabel
      )
    }
  }
}

struct NoteValidationResult: Equatable {
  let titleError: NoteValidationError?
  let contentError: NoteValidationError?
}

enum NoteLimits {
  static let maximumTitleLength = 150
  static let maximumContentLength = 20_000
  static let maximumRawHTMLLength = 200_000
  static let maximumTitleLengthLabel: String = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: maximumTitleLength))
      ?? "\(maximumTitleLength)"
  }()
  static let maximumRawHTMLLengthLabel: String = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: maximumRawHTMLLength))
      ?? "\(maximumRawHTMLLength)"
  }()
  static let maximumContentLengthLabel: String = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: maximumContentLength))
      ?? "\(maximumContentLength)"
  }()

  static func validate(title: String, content: String) -> NoteValidationResult {
    validate(
      title: title,
      serializedContent: content,
      plainText: plainText(from: content)
    )
  }

  static func validate(
    title: String,
    serializedContent: String,
    plainText: String
  ) -> NoteValidationResult {
    let contentError: NoteValidationError?
    if serializedContent.utf8.count > maximumRawHTMLLength {
      contentError = .rawHTMLTooLong
    } else if plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      contentError = .contentEmpty
    } else if plainText.count > maximumContentLength {
      contentError = .contentTooLong
    } else {
      contentError = nil
    }

    return NoteValidationResult(
      titleError: title.count > maximumTitleLength ? .titleTooLong : nil,
      contentError: contentError
    )
  }

  static func plainText(from html: String) -> String {
    let text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    guard let regex = try? NSRegularExpression(pattern: "&(#x[0-9A-Fa-f]+|#\\d+|[A-Za-z][A-Za-z0-9]+);") else {
      return text
    }

    let source = text as NSString
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
    guard !matches.isEmpty else { return text }

    let result = NSMutableString()
    var cursor = 0
    for match in matches {
      result.append(source.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
      let entity = source.substring(with: match.range)
      result.append(decodeEntity(entity))
      cursor = NSMaxRange(match.range)
    }
    result.append(source.substring(from: cursor))
    return result as String
  }

  private static func decodeEntity(_ entity: String) -> String {
    let namedEntities: [String: String] = [
      "nbsp": " ", "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
      "copy": "©", "reg": "®", "hellip": "…", "ndash": "–", "mdash": "—",
      "laquo": "«", "raquo": "»", "bull": "•", "middot": "·"
    ]
    let value = String(entity.dropFirst().dropLast())
    if let namedValue = namedEntities[value] { return namedValue }

    let radix: Int
    let digits: Substring
    if value.hasPrefix("#x") || value.hasPrefix("#X") {
      radix = 16
      digits = value.dropFirst(2)
    } else if value.hasPrefix("#") {
      radix = 10
      digits = value.dropFirst()
    } else {
      return entity
    }
    guard let scalarValue = UInt32(digits, radix: radix),
          let scalar = UnicodeScalar(scalarValue)
    else { return entity }
    return String(scalar)
  }
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

struct NoteCitation: Identifiable, Equatable, Sendable {
  let id: String
  let sourceId: String
  let sourceTitle: String
  let sourceType: String
  let sourceAuthor: String?
  let passageId: String?
  let snippet: String?
  let locationLabel: String?
  let pageReference: String?
  let sectionReference: String?
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
  let originConversationId: String?
  let originMessageId: String?
  let citations: [NoteCitation]

  init(
    id: String,
    researchSpaceId: String,
    title: String,
    originType: NoteOriginType,
    content: String,
    createdAt: Date,
    updatedAt: Date,
    citationCount: Int?,
    originConversationId: String? = nil,
    originMessageId: String? = nil,
    citations: [NoteCitation] = []
  ) {
    self.id = id
    self.researchSpaceId = researchSpaceId
    self.title = title
    self.originType = originType
    self.content = content
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.citationCount = citationCount
    self.originConversationId = originConversationId
    self.originMessageId = originMessageId
    self.citations = citations
  }

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
enum NoteRepositoryError: LocalizedError, Equatable {
  case conversionFailed(String)

  var errorDescription: String? {
    switch self {
    case .conversionFailed(let message): return message
    }
  }
}
