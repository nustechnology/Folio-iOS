protocol NoteRepositoryProtocol {
  func fetchNotes(query: NoteListQuery) async throws -> NoteListResult
  func fetchNote(spaceId: String, noteId: String) async throws -> Note
  func createNote(spaceId: String, title: String, content: String) async throws -> Note
  func updateNote(spaceId: String, noteId: String, title: String, content: String) async throws
    -> Note
  func deleteNote(spaceId: String, noteId: String) async throws
}
