protocol NoteRepositoryProtocol {
  func fetchNotes(query: NoteListQuery) async throws -> NoteListResult
  func fetchNote(spaceId: String, noteId: String) async throws -> Note
  func createNote(spaceId: String, title: String, content: String) async throws -> Note
  func createSavedAnswerNote(
    spaceId: String, title: String, content: String, project: String?,
    originConversationId: String?, originMessageId: String?,
    citationCount: Int?, citations: [SavedAnswerCitationDTO]?
  ) async throws -> Note
  func convertNoteToSource(spaceId: String, noteId: String, title: String) async throws -> Source
  func updateNote(spaceId: String, noteId: String, title: String, content: String) async throws
    -> Note
  func deleteNote(spaceId: String, noteId: String) async throws
}
