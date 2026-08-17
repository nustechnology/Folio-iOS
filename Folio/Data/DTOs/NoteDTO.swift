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
  let content: String
  let createdAt: Date
  let updatedAt: Date
  let citationCount: Int?
  func toDomain() -> Note {
    Note(
      id: id, researchSpaceId: researchSpaceId, title: title,
      originType: NoteOriginType(rawValue: originType) ?? .userCreated, content: content,
      createdAt: createdAt, updatedAt: updatedAt, citationCount: citationCount)
  }
}
struct UpdateNoteRequestDTO: Encodable {
  let title: String
  let content: String
}
struct ConvertNoteRequestDTO: Encodable {
  let title: String
}
