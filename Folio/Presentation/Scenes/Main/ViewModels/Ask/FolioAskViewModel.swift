import SwiftUI
import Combine

// MARK: - ViewModel
// Mirrors HomeViewModel.kt's onAskSubmit/onAskStop/onAskSaveAsNote/onAskFeedback/
// applyAskScope/refreshAskSuggestions. Suggestions are fetched from
// GET /api/v1/spaces/{spaceId}/ask/suggestions; answers stream from
// POST /api/v1/spaces/{spaceId}/ask via StreamAskAnswerUseCase (SSE).

@MainActor
final class FolioAskViewModel: ViewModelProtocol {
    struct State: Equatable {
        var messages: [AskMessage] = []
        var scope: AskScope = .entireSpace
        var selectedSourceID: String? = nil
        var suggestions: [String] = []
        var isSuggestionsLoading: Bool = false
        var savingMessageID: String? = nil
        var conversationEpoch: Int = 0
        var isLoadingConversation: Bool = false
        var conversationLoadError: String? = nil
    }

    enum Action {
        case submit(String)
        case stop
        case saveAsNoteRequested(String)
        case saveAsNoteDismissed
        case saveAsNoteTitleChanged(String)
        case saveAsNoteContentChanged(String)
        case saveAsNoteConfirmed(String)
        case feedback(String, useful: Bool)
        case scopeOptionSelected(sourceID: String?)
        case citationTap(AskCitation)
        case newConversation
        case retryConversationLoad
    }

    @Published private(set) var state: State = .init()
    @Published var previewCitation: AskCitation? = nil
    @Published var saveDraft: SaveAskNoteDraft? = nil
    @Published private(set) var saveError: String?
    @Published var toastMessage: ToastMessage? = nil

    private static let noteTitleMaxLength = 150
    private static let defaultSavedAnswerTitle = String(localized: "Saved answer")
    private static let untitledNoteTitle = String(localized: "Untitled Note")
    private static let streamFailureMessage = String(localized: "Something went wrong. Please try again.")

    @Published private var sources: [FolioSource] = []
    private var streamTask: Task<Void, Never>?
    private var suggestionsTask: Task<Void, Never>?
    private var conversationDetailTask: Task<Void, Never>?
    private var nextMessageID = 0
    private var spaceId: String?
    private var loadedSuggestionsSpaceId: String?
    private var conversationId: String?
    private var lastFailedConversation: AskConversation?
    private var lastFailedSpaceId: String?
    private let fetchAskSuggestionsUseCase: any FetchAskSuggestionsUseCaseProtocol
    private let streamAskAnswerUseCase: any StreamAskAnswerUseCaseProtocol
    private let fetchAskConversationDetailUseCase: any FetchAskConversationDetailUseCaseProtocol
    private let sendFeedbackUseCase: any SendFeedbackUseCaseProtocol
    private let createSavedAnswerNoteUseCase: any CreateSavedAnswerNoteUseCaseProtocol
    var onConversationCreated: (() -> Void)?
    var onNoteCreated: (() -> Void)?

    var isStreaming: Bool {
        state.messages.last(where: { $0.role == .assistant })?.isStreaming ?? false
    }

    var readySourceCount: Int { sources.filter { $0.status == .ready }.count }
    var readySources: [FolioSource] { sources.filter { $0.status == .ready } }

    /// Mirrors `hasAskEvidence()`: Entire Space just needs any Ready source, but
    /// Current Source needs the *specific* selected source to be Ready.
    var hasEvidence: Bool {
        switch state.scope {
        case .entireSpace:
            return readySourceCount > 0
        case .currentSource:
            return sources.first { $0.id == state.selectedSourceID }?.status == .ready
        }
    }

    var displaySuggestions: [String] {
        if state.suggestions.isEmpty {
            return [
                String(localized: "Summarize all the evidence."),
                String(localized: "What problems appear most often?"),
                String(localized: "Where do the sources disagree?")
            ]
        }
        return Array(state.suggestions.prefix(3))
    }

    var activeConversationTitle: String? {
        state.messages.first(where: { $0.role == .user })?.content
    }

    var scopeChipLabel: String {
        switch state.scope {
        case .entireSpace:
            return String(localized: "Entire space")
        case .currentSource:
            return sources.first { $0.id == state.selectedSourceID }?.title
                ?? String(localized: "Current source")
        }
    }

    init(
        sources: [FolioSource] = [],
        fetchAskSuggestionsUseCase: any FetchAskSuggestionsUseCaseProtocol,
        streamAskAnswerUseCase: any StreamAskAnswerUseCaseProtocol,
        fetchAskConversationDetailUseCase: any FetchAskConversationDetailUseCaseProtocol,
        sendFeedbackUseCase: any SendFeedbackUseCaseProtocol,
        createSavedAnswerNoteUseCase: any CreateSavedAnswerNoteUseCaseProtocol
    ) {
        self.sources = sources
        self.fetchAskSuggestionsUseCase = fetchAskSuggestionsUseCase
        self.streamAskAnswerUseCase = streamAskAnswerUseCase
        self.fetchAskConversationDetailUseCase = fetchAskConversationDetailUseCase
        self.sendFeedbackUseCase = sendFeedbackUseCase
        self.createSavedAnswerNoteUseCase = createSavedAnswerNoteUseCase
    }

    deinit {
        streamTask?.cancel()
        suggestionsTask?.cancel()
        conversationDetailTask?.cancel()
    }

    func updateSources(_ sources: [FolioSource], spaceId: String?) {
        self.sources = sources
        self.spaceId = spaceId
        refreshSuggestions()
    }

    func handle(_ action: Action) {
        switch action {
        case .submit(let question):
            submit(question)
        case .stop:
            stopStreaming()
        case .saveAsNoteRequested(let messageID):
            requestSaveAsNote(messageID)
        case .saveAsNoteDismissed:
            saveDraft = nil
            saveError = nil
        case .saveAsNoteTitleChanged(let title):
            saveDraft?.title = title
            saveError = nil
        case .saveAsNoteContentChanged(let content):
            saveDraft?.content = content
            saveError = nil
        case .saveAsNoteConfirmed(let content):
            confirmSaveAsNote(content: content)
        case .feedback(let messageID, let useful):
            setFeedback(messageID: messageID, useful: useful)
        case .scopeOptionSelected(let sourceID):
            applyScope(sourceID: sourceID)
        case .citationTap(let citation):
            previewCitation = citation
        case .newConversation:
            startNewConversation()
        case .retryConversationLoad:
            retryConversationLoad()
        }
    }

    /// Resets chat history and re-initializes the empty state while keeping the
    /// currently selected scope (Entire Space or a specific source) unchanged.
    private func startNewConversation() {
        streamTask?.cancel()
        streamTask = nil
        conversationDetailTask?.cancel()
        conversationDetailTask = nil
        state.messages = []
        state.savingMessageID = nil
        state.conversationEpoch += 1
        state.isLoadingConversation = false
        conversationId = nil
        saveDraft = nil
        saveError = nil
        previewCitation = nil
        lastFailedConversation = nil
        lastFailedSpaceId = nil
    }

    private func retryConversationLoad() {
        guard let conversation = lastFailedConversation, let spaceId = lastFailedSpaceId else { return }
        openExistingConversation(conversation, spaceId: spaceId)
    }

    /// Continues an existing conversation selected from the conversation list,
    /// fetching its prior messages and scope so the user sees what was already
    /// asked before appending new questions under the same `conversationId`.
    ///
    /// `spaceId` is passed explicitly rather than relying on `self.spaceId`:
    /// this can be called from the conversation list before `FolioAskView` has
    /// ever appeared, i.e. before its `onAppear` has had a chance to set it via
    /// `updateSources`.
    func openExistingConversation(_ conversation: AskConversation, spaceId: String) {
        self.spaceId = spaceId
        streamTask?.cancel()
        streamTask = nil
        conversationDetailTask?.cancel()
        state.messages = []
        state.savingMessageID = nil
        state.conversationEpoch += 1
        conversationId = conversation.id
        saveDraft = nil
        saveError = nil
        previewCitation = nil

        state.isLoadingConversation = true
        state.conversationLoadError = nil
        let epoch = state.conversationEpoch
        conversationDetailTask = Task { [weak self] in
            await self?.loadConversationDetail(
                spaceId: spaceId, conversationId: conversation.id, epoch: epoch)
        }
    }

    private func loadConversationDetail(spaceId: String, conversationId: String, epoch: Int) async {
        do {
            let detail = try await fetchAskConversationDetailUseCase.execute(
                spaceId: spaceId, conversationId: conversationId)
            guard !Task.isCancelled, epoch == state.conversationEpoch else { return }
            applyScope(fromDetail: detail.scope)
            state.messages = detail.messages.map(Self.mapMessage)
            state.isLoadingConversation = false
            state.conversationLoadError = nil
            lastFailedConversation = nil
            lastFailedSpaceId = nil
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled, epoch == state.conversationEpoch else { return }
            Logger.error("Failed to load conversation \(conversationId): \(error)")
            state.isLoadingConversation = false
            state.conversationLoadError = String(localized: "Failed to load conversation. Please try again.")
            lastFailedConversation = AskConversation(
                id: conversationId, title: "", createdAt: Date(), updatedAt: Date())
            lastFailedSpaceId = spaceId
        }
    }

    /// Applies the scope the conversation was created with, without resetting
    /// messages/conversationId the way user-driven `applyScope(sourceID:)` does.
    private func applyScope(fromDetail scope: AskConversationScope) {
        if scope.type == "source", let sourceId = scope.sourceId {
            state.scope = .currentSource
            state.selectedSourceID = sourceId
        } else {
            state.scope = .entireSpace
            state.selectedSourceID = nil
        }
    }

    private static func mapMessage(_ message: AskConversationMessage) -> AskMessage {
        let (cleanContent, finalLimitation) = extractLimitation(from: message.content, existingLimitation: message.limitation)
        return AskMessage(
            id: message.id,
            role: message.role == .assistant ? .assistant : .user,
            content: cleanContent,
            isStreaming: false,
            wasStopped: message.stopped,
            citations: message.citations.map(mapCitation),
            limitation: finalLimitation,
            isSavedAsNote: message.savedNoteId != nil,
            feedback: message.feedback == .useful ? .useful : (message.feedback == .notUseful ? .notUseful : .none),
            serverMessageID: message.id
        )
    }

    func openCitationInSource() -> FolioSource? {
        guard let citation = previewCitation, citation.canOpenInSource else { return nil }
        previewCitation = nil
        return sources.first { $0.id == citation.sourceID }
    }

    private func submit(_ question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, hasEvidence, !isStreaming, let spaceId else { return }

        let userMessage = AskMessage(id: nextID(), role: .user, content: trimmed)
        let assistantID = nextID()
        let assistantMessage = AskMessage(id: assistantID, role: .assistant, content: "", isStreaming: true)
        state.messages.append(userMessage)
        state.messages.append(assistantMessage)

        let scope: AskAnswerScope = state.scope == .currentSource ? .source : .space
        let sourceId = state.scope == .currentSource ? state.selectedSourceID : nil

        streamTask?.cancel()
        streamTask = Task { [weak self] in
            await self?.streamAnswer(
                for: assistantID, spaceId: spaceId, question: trimmed, scope: scope, sourceId: sourceId)
        }
    }

    private func streamAnswer(
        for messageID: String, spaceId: String, question: String, scope: AskAnswerScope, sourceId: String?
    ) async {
        do {
            let events = streamAskAnswerUseCase.execute(
                spaceId: spaceId, question: question, scope: scope, sourceId: sourceId,
                conversationId: conversationId)
            for try await event in events {
                if Task.isCancelled { return }
                handle(event, messageID: messageID)
            }
            if Task.isCancelled { return }
            updateMessage(id: messageID) {
                guard $0.isStreaming else { return }
                if $0.content.isEmpty { $0.content = Self.streamFailureMessage }
                $0.isStreaming = false
            }
        } catch {
            if Task.isCancelled { return }
            Logger.error("Ask stream failed: \(error)")
            let message = (error as? NetworkError)?.errorDescription ?? Self.streamFailureMessage
            updateMessage(id: messageID) {
                if $0.content.isEmpty { $0.content = message }
                $0.isStreaming = false
            }
        }
    }

    private func handle(_ event: AskAnswerStreamEvent, messageID: String) {
        switch event {
        case .start(let conversationId, let serverMessageID):
            let isNew = self.conversationId == nil
            self.conversationId = conversationId
            updateMessage(id: messageID) { $0.serverMessageID = serverMessageID }
            if isNew { onConversationCreated?() }
        case .token(let text):
            updateMessage(id: messageID) { $0.content += text }
        case .citations(let citations):
            updateMessage(id: messageID) { $0.citations = citations.map(Self.mapCitation) }
        case .done(let serverMessageID, let content, let citations, let limitation, let stopped):
            let (cleanContent, finalLimitation) = Self.extractLimitation(from: content, existingLimitation: limitation)
            updateMessage(id: messageID) {
                $0.serverMessageID = serverMessageID
                $0.content = cleanContent
                $0.citations = citations.map(Self.mapCitation)
                $0.limitation = finalLimitation
                $0.isStreaming = false
                $0.wasStopped = stopped
            }
        case .error(let message):
            Logger.error("Ask stream reported error: \(message)")
            updateMessage(id: messageID) {
                if $0.content.isEmpty { $0.content = message.isEmpty ? Self.streamFailureMessage : message }
                $0.isStreaming = false
            }
        }
    }

    static func extractLimitation(from content: String, existingLimitation: String?) -> (cleanContent: String, limitation: String?) {
        var limitation = existingLimitation?.trimmingCharacters(in: .whitespacesAndNewlines)
        if limitation?.isEmpty == true { limitation = nil }

        let pattern = "(?i)\\n*\\s*LIMITATION:\\s*([\\s\\S]*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (content.trimmingCharacters(in: .whitespacesAndNewlines), limitation)
        }

        let range = NSRange(content.startIndex..., in: content)
        if let match = regex.firstMatch(in: content, options: [], range: range) {
            if let limRange = Range(match.range(at: 1), in: content) {
                let extracted = String(content[limRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if limitation == nil && !extracted.isEmpty {
                    limitation = extracted
                }
            }
            if let fullMatchRange = Range(match.range(at: 0), in: content) {
                let clean = String(content[..<fullMatchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (clean.isEmpty ? content : clean, limitation)
            }
        }

        return (content.trimmingCharacters(in: .whitespacesAndNewlines), limitation)
    }

    private static func mapCitation(_ citation: AskAnswerCitation) -> AskCitation {
        AskCitation(
            index: citation.index,
            sourceID: citation.sourceId,
            sourceTitle: citation.sourceTitle,
            sourceKind: FolioSourceKind(rawValue: citation.sourceKind),
            locationLabel: citation.locationLabel,
            evidenceText: citation.evidenceText
        )
    }

    private func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        guard let last = state.messages.last, last.role == .assistant, last.isStreaming else { return }
        let (cleanContent, finalLimitation) = Self.extractLimitation(from: last.content, existingLimitation: last.limitation)
        updateMessage(id: last.id) {
            $0.content = cleanContent
            $0.limitation = finalLimitation
            $0.isStreaming = false
            $0.wasStopped = true
        }
    }

    /// Opens the Save-as-note draft sheet, prefilling the title from the question
    /// that preceded this answer. Mirrors `HomeAskDelegate.onAskSaveAsNote`.
    private func requestSaveAsNote(_ messageID: String) {
        guard saveDraft == nil, state.savingMessageID == nil else { return }
        guard let messageIndex = state.messages.firstIndex(where: { $0.id == messageID && $0.role == .assistant }) else { return }
        let message = state.messages[messageIndex]
        guard !message.isSavedAsNote, !message.isStreaming, !message.content.isEmpty else { return }

        let question = state.messages[..<messageIndex]
            .last { $0.role == .user }?
            .content ?? ""
        saveDraft = SaveAskNoteDraft(
            messageID: messageID,
            serverMessageID: message.serverMessageID,
            initialTitle: titleFromQuestion(question),
            content: AskSavedNoteFormatter.formatContent(
                answer: message.content,
                limitation: message.limitation,
                citations: message.citations
            ),
            limitation: message.limitation,
            citations: message.citations
        )
        saveError = nil
    }

    private func titleFromQuestion(_ question: String) -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let clamped = String(trimmed.prefix(Self.noteTitleMaxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        return clamped.isEmpty ? Self.defaultSavedAnswerTitle : clamped
    }

    /// Saves the answer as a note via the Notes API. Mirrors `HomeAskDelegate.onAskSaveAsNoteConfirm`.
    private func confirmSaveAsNote(content: String) {
        guard let draft = saveDraft, state.savingMessageID == nil else { return }
        guard let spaceId, let conversationId, let serverMessageID = draft.serverMessageID else {
            saveError = String(localized: "Failed to save as note. Please try again.")
            return
        }
        let title = draft.title
        let validation = NoteLimits.validate(title: title, content: content)
        guard validation.titleError == nil, validation.contentError == nil
        else {
            return
        }
        let messageID = draft.messageID
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? Self.defaultSavedAnswerTitle : trimmedTitle

        state.savingMessageID = messageID
        saveError = nil

        Task {
            do {
                _ = try await createSavedAnswerNoteUseCase.execute(
                    spaceId: spaceId,
                    title: finalTitle,
                    content: content,
                    project: nil,
                    originConversationId: conversationId,
                    originMessageId: serverMessageID,
                    citationCount: draft.citations.count,
                    citations: nil)
                updateMessage(id: messageID) { $0.isSavedAsNote = true }
                state.savingMessageID = nil
                saveDraft = nil
                saveError = nil
                onNoteCreated?()
                toastMessage = .success(String(localized: "Saved as note"))
            } catch {
                Logger.error("Failed to save as note: \(error)")
                state.savingMessageID = nil
                saveError = String(localized: "Failed to save as note. Please try again.")
                toastMessage = .error(saveError ?? String(localized: "Failed to save as note. Please try again."))
            }
        }
    }

    private func setFeedback(messageID: String, useful: Bool) {
        updateMessage(id: messageID) { $0.feedback = useful ? .useful : .notUseful }
        guard let spaceId, let conversationId else { return }
        let rating = useful ? "useful" : "not_useful"
        Task {
            do {
                try await sendFeedbackUseCase.execute(
                    spaceId: spaceId, conversationId: conversationId, messageId: messageID, rating: rating)
                toastMessage = .success(String(localized: "Feedback recorded"))
            } catch {
                Logger.error("Failed to send feedback: \(error)")
                toastMessage = .error(String(localized: "Failed to record feedback. Please try again."))
            }
        }
    }

    private func applyScope(sourceID: String?) {
        let newScope: AskScope = sourceID == nil ? .entireSpace : .currentSource
        streamTask?.cancel()
        streamTask = nil
        state.scope = newScope
        state.selectedSourceID = sourceID
        state.messages = []
        state.conversationEpoch += 1
        conversationId = nil
        saveError = nil
        refreshSuggestions()
    }

    /// Fetches suggestions once per space and reused across tab switches instead of refetching every time the Ask
    /// tab is re-shown.
    private func refreshSuggestions() {
        guard let spaceId else {
            suggestionsTask?.cancel()
            loadedSuggestionsSpaceId = nil
            state.suggestions = []
            state.isSuggestionsLoading = false
            return
        }
        let scope = state.scope == .currentSource ? "source" : "space"
        let sourceId = state.selectedSourceID
        let cacheKey = "\(spaceId)|\(scope)|\(sourceId ?? "")"
        guard loadedSuggestionsSpaceId != cacheKey else { return }
        loadedSuggestionsSpaceId = cacheKey

        suggestionsTask?.cancel()
        state.suggestions = []
        state.isSuggestionsLoading = true
        suggestionsTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.fetchAskSuggestionsUseCase.execute(
                    spaceId: spaceId, scope: scope, sourceId: sourceId)
                guard !Task.isCancelled else { return }
                self.state.suggestions = result.suggestions
                self.state.isSuggestionsLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                Logger.error("Failed to load ask suggestions: \(error)")
                self.state.suggestions = []
                self.state.isSuggestionsLoading = false
            }
        }
    }

    private func updateMessage(id: String, _ transform: (inout AskMessage) -> Void) {
        guard let index = state.messages.firstIndex(where: { $0.id == id }) else { return }
        transform(&state.messages[index])
    }

    private func nextID() -> String {
        defer { nextMessageID += 1 }
        return "ask-msg-\(nextMessageID)"
    }
}
