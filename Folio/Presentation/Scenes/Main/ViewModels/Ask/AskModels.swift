import Foundation

// MARK: - Models
// Mirrors Folio-Android presentation/home/HomeUiState.kt (Ask* types) and
// domain/model/AskCitation.kt so the two clients share identical Ask semantics.

enum AskMessageRole: Equatable {
    case user
    case assistant
}

enum AskFeedback: Equatable {
    case none
    case useful
    case notUseful
}

enum AskScope: Equatable {
    case entireSpace
    case currentSource
}

struct AskCitation: Identifiable, Equatable {
    let index: Int
    let sourceID: String
    let sourceTitle: String
    let sourceKind: FolioSourceKind?
    let locationLabel: String
    let evidenceText: String

    var id: Int { index }

    var canOpenInSource: Bool { !sourceID.isEmpty && sourceID != "unknown" }

    var badgeLabel: String {
        sourceKind?.badge ?? String(localized: "SOURCE")
    }
}

struct AskMessage: Identifiable, Equatable {
    let id: String
    let role: AskMessageRole
    var content: String
    var isStreaming: Bool = false
    var wasStopped: Bool = false
    var citations: [AskCitation] = []
    var limitation: String? = nil
    var isSavedAsNote: Bool = false
    var feedback: AskFeedback = .none
    var serverMessageID: String? = nil
}

/// Prefill state for the Save-Ask-Answer-as-Note sheet, mirrors `SaveAskNoteDraft` in HomeUiState.kt.
struct SaveAskNoteDraft: Identifiable, Equatable {
    let messageID: String
    let serverMessageID: String?
    let initialTitle: String
    let initialContent: String
    var title: String
    var content: String
    let limitation: String?
    let citations: [AskCitation]

    var id: String { messageID }

    init(
        messageID: String,
        serverMessageID: String?,
        initialTitle: String,
        content: String,
        limitation: String?,
        citations: [AskCitation]
    ) {
        self.messageID = messageID
        self.serverMessageID = serverMessageID
        self.initialTitle = initialTitle
        self.initialContent = content
        self.title = initialTitle
        self.content = content
        self.limitation = limitation
        self.citations = citations
    }

    var hasUnsavedChanges: Bool {
        title != initialTitle || content != initialContent
    }
}

/// First letter of the display name, falling back to the first letter of the email.
func initialsFromDisplayName(_ displayName: String?, emailFallback: String?) -> String {
    let trimmed = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let source = trimmed.isEmpty ? (emailFallback ?? "") : trimmed
    return source.first.map { String($0).uppercased() } ?? ""
}
