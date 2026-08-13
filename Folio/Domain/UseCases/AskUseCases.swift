protocol FetchAskSuggestionsUseCaseProtocol {
  func execute(spaceId: String, scope: String, sourceId: String?) async throws -> AskSuggestionsResult
}

final class FetchAskSuggestionsUseCase: FetchAskSuggestionsUseCaseProtocol {
  private let repository: AskRepositoryProtocol
  init(repository: AskRepositoryProtocol) { self.repository = repository }
  func execute(spaceId: String, scope: String, sourceId: String?) async throws -> AskSuggestionsResult {
    try await repository.fetchSuggestions(spaceId: spaceId, scope: scope, sourceId: sourceId)
  }
}

protocol FetchAskConversationsUseCaseProtocol {
  func execute(query: AskConversationListQuery) async throws -> AskConversationListResult
}

final class FetchAskConversationsUseCase: FetchAskConversationsUseCaseProtocol {
  private let repository: AskRepositoryProtocol
  init(repository: AskRepositoryProtocol) { self.repository = repository }
  func execute(query: AskConversationListQuery) async throws -> AskConversationListResult {
    try await repository.fetchConversations(query: query)
  }
}

protocol FetchAskConversationDetailUseCaseProtocol {
  func execute(spaceId: String, conversationId: String) async throws -> AskConversationDetail
}

final class FetchAskConversationDetailUseCase: FetchAskConversationDetailUseCaseProtocol {
  private let repository: AskRepositoryProtocol
  init(repository: AskRepositoryProtocol) { self.repository = repository }
  func execute(spaceId: String, conversationId: String) async throws -> AskConversationDetail {
    try await repository.fetchConversationDetail(spaceId: spaceId, conversationId: conversationId)
  }
}

protocol SendFeedbackUseCaseProtocol {
  func execute(spaceId: String, conversationId: String, messageId: String, rating: String) async throws
}

final class SendFeedbackUseCase: SendFeedbackUseCaseProtocol {
  private let repository: AskRepositoryProtocol
  init(repository: AskRepositoryProtocol) { self.repository = repository }
  func execute(spaceId: String, conversationId: String, messageId: String, rating: String) async throws {
    try await repository.sendFeedback(spaceId: spaceId, conversationId: conversationId, messageId: messageId, rating: rating)
  }
}

protocol DeleteConversationUseCaseProtocol {
  func execute(spaceId: String, conversationId: String) async throws
}

final class DeleteConversationUseCase: DeleteConversationUseCaseProtocol {
  private let repository: AskRepositoryProtocol
  init(repository: AskRepositoryProtocol) { self.repository = repository }
  func execute(spaceId: String, conversationId: String) async throws {
    try await repository.deleteConversation(spaceId: spaceId, conversationId: conversationId)
  }
}

protocol RenameConversationUseCaseProtocol {
  func execute(spaceId: String, conversationId: String, title: String) async throws
}

final class RenameConversationUseCase: RenameConversationUseCaseProtocol {
  private let repository: AskRepositoryProtocol
  init(repository: AskRepositoryProtocol) { self.repository = repository }
  func execute(spaceId: String, conversationId: String, title: String) async throws {
    try await repository.renameConversation(spaceId: spaceId, conversationId: conversationId, title: title)
  }
}

protocol StreamAskAnswerUseCaseProtocol {
  func execute(
    spaceId: String,
    question: String,
    scope: AskAnswerScope,
    sourceId: String?,
    conversationId: String?
  ) -> AsyncThrowingStream<AskAnswerStreamEvent, Error>
}

final class StreamAskAnswerUseCase: StreamAskAnswerUseCaseProtocol {
  private let repository: AskRepositoryProtocol
  init(repository: AskRepositoryProtocol) { self.repository = repository }
  func execute(
    spaceId: String,
    question: String,
    scope: AskAnswerScope,
    sourceId: String?,
    conversationId: String?
  ) -> AsyncThrowingStream<AskAnswerStreamEvent, Error> {
    repository.streamAnswer(
      spaceId: spaceId, question: question, scope: scope, sourceId: sourceId, conversationId: conversationId)
  }
}
