import Foundation

final class AskRepository: AskRepositoryProtocol {
  private let networkService: NetworkServiceProtocol
  private let baseURL: URL
  private let accessTokenProvider: AccessTokenProvider?

  init(
    networkService: NetworkServiceProtocol,
    baseURL: URL,
    accessTokenProvider: AccessTokenProvider? = nil
  ) {
    self.networkService = networkService
    self.baseURL = baseURL
    self.accessTokenProvider = accessTokenProvider
  }

  func fetchSuggestions(spaceId: String, scope: String, sourceId: String?) async throws -> AskSuggestionsResult {
    let response: AskSuggestionsResponseDTO = try await networkService.request(
      AskSuggestionsEndpoint(spaceId: spaceId, scope: scope, sourceId: sourceId))
    return response.toDomain()
  }

  func fetchConversations(query: AskConversationListQuery) async throws -> AskConversationListResult {
    let response: AskConversationListResponseDTO = try await networkService.request(
      AskConversationListEndpoint(query: query))
    return response.toDomain()
  }

  func fetchConversationDetail(spaceId: String, conversationId: String) async throws -> AskConversationDetail {
    let response: AskConversationDetailResponseDTO = try await networkService.request(
      AskConversationDetailEndpoint(spaceId: spaceId, conversationId: conversationId))
    return response.toDomain()
  }

  func sendFeedback(spaceId: String, conversationId: String, messageId: String, rating: String) async throws {
    try await networkService.requestVoid(
      AskFeedbackEndpoint(spaceId: spaceId, conversationId: conversationId, messageId: messageId, rating: rating))
  }

  func deleteConversation(spaceId: String, conversationId: String) async throws {
    try await networkService.requestVoid(
      DeleteConversationEndpoint(spaceId: spaceId, conversationId: conversationId))
  }

  func renameConversation(spaceId: String, conversationId: String, title: String) async throws {
    try await networkService.requestVoid(
      RenameConversationEndpoint(spaceId: spaceId, conversationId: conversationId, title: title))
  }

  func streamAnswer(
    spaceId: String,
    question: String,
    scope: AskAnswerScope,
    sourceId: String?,
    conversationId: String?
  ) -> AsyncThrowingStream<AskAnswerStreamEvent, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          var endpoint = try AskStreamAnswerEndpoint(
            baseURL: baseURL,
            spaceId: spaceId,
            question: question,
            scope: scope.rawValue,
            sourceId: sourceId,
            conversationId: conversationId,
            accessToken: accessTokenProvider?.accessToken
          )
          let client = AskAnswerSSEClient()
          var retried = false
          while true {
            do {
              for try await event in client.connect(endpoint: endpoint) {
                continuation.yield(event)
              }
              break
            } catch let error as NetworkError {
              guard !retried,
                    case .httpError(let statusCode, _) = error,
                    statusCode == 401,
                    let tokenProvider = accessTokenProvider else {
                throw error
              }
              retried = true
              Logger.debug("Ask SSE got 401, refreshing token and retrying")
              do {
                let newToken = try await tokenProvider.refreshToken()
                endpoint = try AskStreamAnswerEndpoint(
                  baseURL: baseURL,
                  spaceId: spaceId,
                  question: question,
                  scope: scope.rawValue,
                  sourceId: sourceId,
                  conversationId: conversationId,
                  accessToken: newToken
                )
              } catch {
                Logger.error("Ask SSE token refresh failed: \(error)")
                throw error
              }
            }
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }
}
