protocol AskRepositoryProtocol {
  func fetchSuggestions(spaceId: String, scope: String, sourceId: String?) async throws -> AskSuggestionsResult
  func fetchConversations(query: AskConversationListQuery) async throws -> AskConversationListResult
  func fetchConversationDetail(spaceId: String, conversationId: String) async throws -> AskConversationDetail
  func sendFeedback(spaceId: String, conversationId: String, messageId: String, rating: String) async throws
  func deleteConversation(spaceId: String, conversationId: String) async throws
  func renameConversation(spaceId: String, conversationId: String, title: String) async throws
  func streamAnswer(
    spaceId: String,
    question: String,
    scope: AskAnswerScope,
    sourceId: String?,
    conversationId: String?
  ) -> AsyncThrowingStream<AskAnswerStreamEvent, Error>
}
