import Foundation

struct NoteListResponseDTO: Decodable {
  let status: String
  let data: NoteListDataDTO
  func toDomain() -> NoteListResult {
    NoteListResult(
      notes: data.notes.map { $0.toDomain() },
      pagination: data.pagination.map {
        NotePagination(
          page: $0.page, limit: $0.limit, totalCount: $0.totalCount, totalPages: $0.totalPages)
      })
  }
}

struct NoteListDataDTO: Decodable {
  let notes: [NoteSummaryDTO]
  let pagination: NotePaginationDTO?
}
struct NotePaginationDTO: Decodable {
  let page: Int
  let limit: Int
  let totalCount: Int
  let totalPages: Int
}
struct NoteSummaryDTO: Decodable {
  let id: String
  let researchSpaceId: String
  let title: String
  let originType: String
  let contentPreview: String
  let createdAt: Date
  let updatedAt: Date
  let citationCount: Int?
  func toDomain() -> NoteSummary {
    NoteSummary(
      id: id, researchSpaceId: researchSpaceId, title: title,
      originType: NoteOriginType(rawValue: originType) ?? .userCreated,
      contentPreview: contentPreview, createdAt: createdAt, updatedAt: updatedAt,
      citationCount: citationCount)
  }
}

struct NoteResponseDTO: Decodable {
  let status: String
  let data: NoteDataDTO
}
struct NoteDataDTO: Decodable { let note: NoteDTO }
struct NoteDTO: Decodable {
  let id: String
  let researchSpaceId: String
  let title: String
  let originType: String
  let originConversationId: String?
  let originMessageId: String?
  let content: String
  let createdAt: Date
  let updatedAt: Date
  let citationCount: Int?
  let citations: [NoteCitationDTO]?

  init(
    id: String,
    researchSpaceId: String,
    title: String,
    originType: String,
    originConversationId: String? = nil,
    originMessageId: String? = nil,
    content: String,
    createdAt: Date,
    updatedAt: Date,
    citationCount: Int?,
    citations: [NoteCitationDTO]? = nil
  ) {
    self.id = id
    self.researchSpaceId = researchSpaceId
    self.title = title
    self.originType = originType
    self.originConversationId = originConversationId
    self.originMessageId = originMessageId
    self.content = content
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.citationCount = citationCount
    self.citations = citations
  }

  func toDomain() -> Note {
    Note(
      id: id, researchSpaceId: researchSpaceId, title: title,
      originType: NoteOriginType(rawValue: originType) ?? .userCreated, content: content,
      createdAt: createdAt, updatedAt: updatedAt, citationCount: citationCount,
      originConversationId: originConversationId, originMessageId: originMessageId,
      citations: citations?.map { $0.toDomain() } ?? [])
  }
}

struct NoteCitationDTO: Decodable {
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

  func toDomain() -> NoteCitation {
    NoteCitation(
      id: id,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      sourceType: sourceType,
      sourceAuthor: sourceAuthor,
      passageId: passageId,
      snippet: snippet,
      locationLabel: locationLabel,
      pageReference: pageReference,
      sectionReference: sectionReference
    )
  }
}
struct CreateNoteRequestDTO: Encodable {
  let title: String
  let content: String
}
struct UpdateNoteRequestDTO: Encodable {
  let title: String
  let content: String
}
struct ConvertNoteRequestDTO: Encodable {
  let title: String
}
