import Foundation

enum AskAnswerScope: String, Sendable {
    case space
    case source
}

struct AskAnswerCitation: Equatable, Sendable {
    let index: Int
    let sourceId: String
    let sourceTitle: String
    let sourceKind: String
    let locationLabel: String
    let evidenceText: String
}

enum AskAnswerStreamEvent: Sendable {
    case start(conversationId: String, messageId: String)
    case token(String)
    case citations([AskAnswerCitation])
    case done(messageId: String, content: String, citations: [AskAnswerCitation], limitation: String?, stopped: Bool)
    case error(String)
}
