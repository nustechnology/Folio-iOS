import Foundation

struct AskSuggestionsResponseDTO: Decodable {
  let status: String
  let data: AskSuggestionsDataDTO
  func toDomain() -> AskSuggestionsResult {
    AskSuggestionsResult(suggestions: data.suggestions, isDynamic: data.isDynamic)
  }
}

struct AskSuggestionsDataDTO: Decodable {
  let suggestions: [String]
  let isDynamic: Bool
}

struct AskConversationListResponseDTO: Decodable {
  let status: String
  let data: AskConversationListDataDTO
  func toDomain() -> AskConversationListResult {
    AskConversationListResult(
      conversations: data.conversations.map { $0.toDomain() },
      pagination: data.pagination.map {
        AskConversationPagination(
          page: $0.page, limit: $0.limit, totalCount: $0.totalCount, totalPages: $0.totalPages)
      })
  }
}

struct AskConversationListDataDTO: Decodable {
  let conversations: [AskConversationDTO]
  let pagination: AskConversationPaginationDTO?
}

struct AskConversationDTO: Decodable {
  let id: String
  let title: String
  let createdAt: Date
  let updatedAt: Date
  func toDomain() -> AskConversation {
    AskConversation(id: id, title: title, createdAt: createdAt, updatedAt: updatedAt)
  }
}

struct AskConversationPaginationDTO: Decodable {
  let page: Int
  let limit: Int
  let totalCount: Int
  let totalPages: Int
}

struct AskConversationDetailResponseDTO: Decodable {
  let status: String
  let data: AskConversationDetailDataDTO
  func toDomain() -> AskConversationDetail {
    data.conversation.toDomain()
  }
}

struct AskConversationDetailDataDTO: Decodable {
  let conversation: AskConversationDetailDTO
}

struct AskConversationDetailDTO: Decodable {
  let id: String
  let researchSpaceId: String
  let title: String
  let scope: AskConversationScopeDTO
  let messages: [AskConversationMessageDTO]
  let createdAt: Date
  let updatedAt: Date

  func toDomain() -> AskConversationDetail {
    AskConversationDetail(
      id: id,
      researchSpaceId: researchSpaceId,
      title: title,
      scope: AskConversationScope(type: scope.type, sourceId: scope.sourceId),
      messages: messages.map { $0.toDomain() },
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

struct AskConversationScopeDTO: Decodable {
  let type: String
  let sourceId: String?
}

struct AskConversationMessageDTO: Decodable {
  let id: String
  let role: String
  let content: String
  let stopped: Bool?
  let citations: [AskConversationCitationDTO]?
  let limitation: String?
  let feedback: String?
  let savedNoteId: String?
  let createdAt: Date

  func toDomain() -> AskConversationMessage {
    AskConversationMessage(
      id: id,
      role: role == AskConversationMessageRole.assistant.rawValue ? .assistant : .user,
      content: content,
      stopped: stopped ?? false,
      citations: (citations ?? []).enumerated().map { position, citation in
        citation.toDomain(position: position)
      },
      limitation: limitation,
      feedback: feedback == "useful" ? .useful : (feedback == "not_useful" ? .notUseful : nil),
      savedNoteId: savedNoteId,
      createdAt: createdAt
    )
  }
}

struct AskConversationCitationDTO: Decodable {
  let snippet: String
  let sourceId: String
  let sourceType: String
  let sourceTitle: String
  let locationLabel: String?
  let pageReference: String?
  let sectionReference: String?

  func toDomain(position: Int) -> AskAnswerCitation {
    AskAnswerCitation(
      index: position,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      sourceKind: sourceType,
      locationLabel: locationLabel ?? pageReference ?? sectionReference ?? "",
      evidenceText: snippet
    )
  }
}

struct AskQuestionRequestDTO: Encodable {
  let question: String
  let scope: String
  let sourceId: String?
  let conversationId: String?

  enum CodingKeys: String, CodingKey {
    case question
    case scope
    case sourceId
    case conversationId
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(question, forKey: .question)
    try container.encode(scope, forKey: .scope)
    try container.encode(sourceId, forKey: .sourceId)
    try container.encodeIfPresent(conversationId, forKey: .conversationId)
  }
}

struct AskStreamStartDTO: Decodable {
  let conversationId: String
  let messageId: String

  enum CodingKeys: String, CodingKey {
    case conversationId, messageId
    case conversation_id, message_id
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let cid = try? container.decode(String.self, forKey: .conversationId) {
      self.conversationId = cid
    } else {
      self.conversationId = try container.decode(String.self, forKey: .conversation_id)
    }
    if let mid = try? container.decode(String.self, forKey: .messageId) {
      self.messageId = mid
    } else {
      self.messageId = try container.decode(String.self, forKey: .message_id)
    }
  }
}

struct AskStreamTokenDTO: Decodable {
  let text: String
}

struct AskStreamCitationDTO: Decodable {
  let index: Int?
  let sourceId: String?
  let sourceTitle: String?
  let sourceKind: String?
  let sourceType: String?
  let locationLabel: String?
  let pageReference: String?
  let sectionReference: String?
  let evidenceText: String?
  let snippet: String?

  enum CodingKeys: String, CodingKey {
    case index, sourceId, sourceTitle, sourceKind, sourceType, locationLabel, pageReference, sectionReference, evidenceText, snippet
    case source_id, source_title, source_kind, source_type, location_label, page_reference, section_reference, evidence_text
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.index = try? container.decodeIfPresent(Int.self, forKey: .index)
    self.sourceId = (try? container.decodeIfPresent(String.self, forKey: .sourceId))
      ?? (try? container.decodeIfPresent(String.self, forKey: .source_id))
    self.sourceTitle = (try? container.decodeIfPresent(String.self, forKey: .sourceTitle))
      ?? (try? container.decodeIfPresent(String.self, forKey: .source_title))
    self.sourceKind = (try? container.decodeIfPresent(String.self, forKey: .sourceKind))
      ?? (try? container.decodeIfPresent(String.self, forKey: .source_kind))
    self.sourceType = (try? container.decodeIfPresent(String.self, forKey: .sourceType))
      ?? (try? container.decodeIfPresent(String.self, forKey: .source_type))
    self.locationLabel = (try? container.decodeIfPresent(String.self, forKey: .locationLabel))
      ?? (try? container.decodeIfPresent(String.self, forKey: .location_label))
    self.pageReference = (try? container.decodeIfPresent(String.self, forKey: .pageReference))
      ?? (try? container.decodeIfPresent(String.self, forKey: .page_reference))
    self.sectionReference = (try? container.decodeIfPresent(String.self, forKey: .sectionReference))
      ?? (try? container.decodeIfPresent(String.self, forKey: .section_reference))
    self.evidenceText = (try? container.decodeIfPresent(String.self, forKey: .evidenceText))
      ?? (try? container.decodeIfPresent(String.self, forKey: .evidence_text))
    self.snippet = try? container.decodeIfPresent(String.self, forKey: .snippet)
  }

  func toDomain(position: Int) -> AskAnswerCitation {
    AskAnswerCitation(
      index: index ?? position,
      sourceId: sourceId ?? "",
      sourceTitle: sourceTitle ?? "",
      sourceKind: sourceKind ?? sourceType ?? "file",
      locationLabel: locationLabel ?? pageReference ?? sectionReference ?? "",
      evidenceText: evidenceText ?? snippet ?? ""
    )
  }
}

struct AskStreamCitationsDTO: Decodable {
  let citations: [AskStreamCitationDTO]
}

struct AskStreamDoneDTO: Decodable {
  let messageId: String
  let content: String
  let citations: [AskStreamCitationDTO]
  let limitation: String?
  let stopped: Bool

  enum CodingKeys: String, CodingKey {
    case messageId, content, citations, limitation, stopped
    case message_id
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let mid = try? container.decode(String.self, forKey: .messageId) {
      self.messageId = mid
    } else {
      self.messageId = try container.decode(String.self, forKey: .message_id)
    }
    self.content = try container.decode(String.self, forKey: .content)
    self.citations = (try? container.decode([AskStreamCitationDTO].self, forKey: .citations)) ?? []
    self.limitation = try? container.decodeIfPresent(String.self, forKey: .limitation)
    self.stopped = (try? container.decode(Bool.self, forKey: .stopped)) ?? false
  }
}

struct AskStreamErrorDTO: Decodable {
  let message: String
}
