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
