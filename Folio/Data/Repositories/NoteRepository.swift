import Foundation

final class NoteRepository: NoteRepositoryProtocol {
  private let networkService: NetworkServiceProtocol
  init(networkService: NetworkServiceProtocol) { self.networkService = networkService }
  func fetchNotes(query: NoteListQuery) async throws -> NoteListResult {
    let response: NoteListResponseDTO = try await networkService.request(
      NoteListEndpoint(query: query))
    return response.toDomain()
  }
  func fetchNote(spaceId: String, noteId: String) async throws -> Note {
    let response: NoteResponseDTO = try await networkService.request(
      NoteDetailEndpoint(spaceId: spaceId, noteId: noteId))
    return response.data.note.toDomain()
  }
  func createNote(spaceId: String, title: String, content: String) async throws -> Note {
    let response: NoteResponseDTO = try await networkService.request(
      CreateNoteEndpoint(spaceId: spaceId, title: title, content: content))
    return response.data.note.toDomain()
  }
  func createSavedAnswerNote(
    spaceId: String, title: String, content: String, project: String?,
    originConversationId: String?, originMessageId: String?,
    citationCount: Int?, citations: [SavedAnswerCitationDTO]?
  ) async throws -> Note {
    let origin: NoteOriginDTO?
    if let cid = originConversationId, let mid = originMessageId {
      origin = NoteOriginDTO(conversationId: cid, messageId: mid)
    } else {
      origin = nil
    }
    let request = CreateNoteRequestDTO(
      title: title, content: content, project: project, origin: origin)
    let response: NoteResponseDTO = try await networkService.request(
      CreateNoteEndpoint(spaceId: spaceId, request: request))
    return response.data.note.toDomain()
  }
  func convertNoteToSource(spaceId: String, noteId: String, title: String) async throws -> Source {
    do {
      let response: SourceResponseDTO = try await networkService.request(
        ConvertNoteToSourceEndpoint(spaceId: spaceId, noteId: noteId, title: title))
      return response.data.source.toDomain()
    } catch let error as NetworkError {
      if let data = error.errorData,
        let apiError = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) {
        throw NoteRepositoryError.conversionFailed(apiError.message)
      }
      throw NoteRepositoryError.conversionFailed(error.localizedDescription)
    }
  }
  func updateNote(spaceId: String, noteId: String, title: String, content: String) async throws
    -> Note
  {
    let response: NoteResponseDTO = try await networkService.request(
      UpdateNoteEndpoint(spaceId: spaceId, noteId: noteId, title: title, content: content))
    return response.data.note.toDomain()
  }
  func deleteNote(spaceId: String, noteId: String) async throws {
    try await networkService.requestVoid(DeleteNoteEndpoint(spaceId: spaceId, noteId: noteId))
  }
}
