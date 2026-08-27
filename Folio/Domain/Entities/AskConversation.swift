import Foundation

struct AskConversation: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
}

struct AskConversationPagination: Equatable, Sendable {
    let page: Int
    let limit: Int
    let totalCount: Int
    let totalPages: Int
}

struct AskConversationListResult: Equatable, Sendable {
    let conversations: [AskConversation]
    let pagination: AskConversationPagination?
}

struct AskConversationListQuery: Equatable, Sendable {
    let spaceId: String
    let page: Int?
    let limit: Int?
    let search: String?

    init(spaceId: String, page: Int? = nil, limit: Int? = nil, search: String? = nil) {
        self.spaceId = spaceId
        self.page = page
        self.limit = limit
        self.search = search
    }
}

enum AskConversationMessageRole: String, Sendable {
    case user
    case assistant
}

struct AskConversationScope: Equatable, Sendable {
    let type: String
    let sourceId: String?
}

struct AskConversationMessage: Equatable, Sendable, Identifiable {
    let id: String
    let role: AskConversationMessageRole
    let content: String
    let stopped: Bool
    let citations: [AskAnswerCitation]
    let limitation: String?
    let feedback: AskFeedbackRating?
    let savedNoteId: String?
    let createdAt: Date
}

enum AskFeedbackRating: String, Sendable {
    case useful
    case notUseful
}

struct AskConversationDetail: Equatable, Sendable {
    let id: String
    let researchSpaceId: String
    let title: String
    let scope: AskConversationScope
    let messages: [AskConversationMessage]
    let createdAt: Date
    let updatedAt: Date
}
