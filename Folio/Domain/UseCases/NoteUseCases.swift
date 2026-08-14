protocol FetchNotesUseCaseProtocol {
  func execute(query: NoteListQuery) async throws -> NoteListResult
}
protocol FetchNoteUseCaseProtocol {
  func execute(spaceId: String, noteId: String) async throws -> Note
}
protocol CreateNoteUseCaseProtocol {
  func execute(spaceId: String, title: String, content: String) async throws -> Note
}
protocol UpdateNoteUseCaseProtocol {
  func execute(spaceId: String, noteId: String, title: String, content: String) async throws -> Note
}
protocol DeleteNoteUseCaseProtocol { func execute(spaceId: String, noteId: String) async throws }

final class FetchNotesUseCase: FetchNotesUseCaseProtocol {
  private let repository: NoteRepositoryProtocol
  init(repository: NoteRepositoryProtocol) { self.repository = repository }
  func execute(query: NoteListQuery) async throws -> NoteListResult {
    try await repository.fetchNotes(query: query)
  }
}

final class FetchNoteUseCase: FetchNoteUseCaseProtocol {
  private let repository: NoteRepositoryProtocol
  init(repository: NoteRepositoryProtocol) { self.repository = repository }
  func execute(spaceId: String, noteId: String) async throws -> Note {
    try await repository.fetchNote(spaceId: spaceId, noteId: noteId)
  }
}

final class CreateNoteUseCase: CreateNoteUseCaseProtocol {
  private let repository: NoteRepositoryProtocol
  init(repository: NoteRepositoryProtocol) { self.repository = repository }
  func execute(spaceId: String, title: String, content: String) async throws -> Note {
    try await repository.createNote(spaceId: spaceId, title: title, content: content)
  }
}

final class UpdateNoteUseCase: UpdateNoteUseCaseProtocol {
  private let repository: NoteRepositoryProtocol
  init(repository: NoteRepositoryProtocol) { self.repository = repository }
  func execute(spaceId: String, noteId: String, title: String, content: String) async throws -> Note
  {
    try await repository.updateNote(
      spaceId: spaceId, noteId: noteId, title: title, content: content)
  }
}

final class DeleteNoteUseCase: DeleteNoteUseCaseProtocol {
  private let repository: NoteRepositoryProtocol
  init(repository: NoteRepositoryProtocol) { self.repository = repository }
  func execute(spaceId: String, noteId: String) async throws {
    try await repository.deleteNote(spaceId: spaceId, noteId: noteId)
  }
}
