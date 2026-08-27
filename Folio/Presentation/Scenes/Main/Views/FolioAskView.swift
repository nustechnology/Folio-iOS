import Combine
import SwiftUI

// MARK: - View

struct FolioAskView: View {
    let sources: [FolioSource]
    let spaceId: String?
    let workspaceTitle: String?
    let onBackToSpaces: () -> Void
    let onOpenSource: (FolioSource) -> Void
    let onSourceAdded: ((Source) -> Void)?
    let uploadSourceUseCase: (any UploadSourceUseCaseProtocol)?
    let userDisplayName: String?
    let userEmail: String?

    /// Owned by the caller (MainView) so the conversation survives tab switches —
    /// this view is re-created every time `MainView.appShell`'s tab switch statement
    /// re-selects the Ask branch, which would otherwise reset a locally-owned
    /// @StateObject and clear askMessages, unlike HomeViewModel's single long-lived
    /// state on Android.
    @ObservedObject private var viewModel: FolioAskViewModel
    @State private var query = ""
    @State private var showScopeSheet = false
    @State private var showConversationSheet = false
    @State private var showAddSourceSheet = false

    init(
        viewModel: FolioAskViewModel,
        sources: [FolioSource],
        spaceId: String? = nil,
        workspaceTitle: String? = nil,
        onBackToSpaces: @escaping () -> Void,
        onOpenSource: @escaping (FolioSource) -> Void,
        onSourceAdded: ((Source) -> Void)? = nil,
        uploadSourceUseCase: (any UploadSourceUseCaseProtocol)? = nil,
        userDisplayName: String? = nil,
        userEmail: String? = nil
    ) {
        self.viewModel = viewModel
        self.sources = sources
        self.spaceId = spaceId
        self.workspaceTitle = workspaceTitle
        self.onBackToSpaces = onBackToSpaces
        self.onOpenSource = onOpenSource
        self.onSourceAdded = onSourceAdded
        self.uploadSourceUseCase = uploadSourceUseCase
        self.userDisplayName = userDisplayName
        self.userEmail = userEmail
    }

    private var userAvatarLabel: String {
        let label = initialsFromDisplayName(userDisplayName, emailFallback: userEmail)
        return label.isEmpty ? String(localized: "You") : label
    }

    var body: some View {
        let conversationTitle = viewModel.activeConversationTitle
        let headerTitle = conversationTitle?.isEmpty == false ? conversationTitle! : String(localized: "Ask")
        let headerSubtitle = conversationTitle?.isEmpty == false ? "" : (workspaceTitle?.isEmpty == false ? workspaceTitle! : String(localized: "Private research assistant"))

        VStack(spacing: 0) {
            FolioContentHeader(
                title: headerTitle,
                subtitle: headerSubtitle,
                onBackToSpaces: onBackToSpaces,
                onPlusTapped: { showConversationSheet = true },
                searchText: .constant("")
            )

            content
        }
        .background(Color.folioCanvas)
        .folioToast(message: $viewModel.toastMessage)
        .onAppear { viewModel.updateSources(sources, spaceId: spaceId) }
        .onChange(of: sources) { _, newSources in viewModel.updateSources(newSources, spaceId: spaceId) }
        .onChange(of: spaceId) { _, newSpaceId in viewModel.updateSources(sources, spaceId: newSpaceId) }
        .sheet(isPresented: $showConversationSheet) {
            ConversationMenuSheet(
                onNewConversation: {
                    viewModel.handle(.newConversation)
                    query = ""
                    showConversationSheet = false
                }
            )
        }
        .sheet(isPresented: $showAddSourceSheet) {
            if let uploadUseCase = uploadSourceUseCase, let spaceId {
                FolioAddSourceSheet(
                    uploadUseCase: uploadUseCase,
                    spaceId: spaceId,
                    onSourceOpened: { source in onSourceAdded?(source) },
                    onSourceAdded: { source in onSourceAdded?(source) }
                )
            }
        }
        .sheet(isPresented: $showScopeSheet) {
            AnswerScopeSheet(
                selectedScope: viewModel.state.scope,
                selectedSourceID: viewModel.state.selectedSourceID,
                sources: sources,
                readySourceCount: viewModel.readySourceCount,
                onSelect: { sourceID in
                    viewModel.handle(.scopeOptionSelected(sourceID: sourceID))
                    showScopeSheet = false
                }
            )
        }
        .sheet(item: Binding(
            get: { viewModel.previewCitation },
            set: { viewModel.previewCitation = $0 }
        )) { citation in
            CitationPreviewSheet(
                citation: citation,
                onOpenInSource: {
                    if let source = viewModel.openCitationInSource() {
                        onOpenSource(source)
                    }
                }
            )
        }
        .sheet(item: Binding(
            get: { viewModel.saveDraft },
            set: { viewModel.saveDraft = $0 }
        )) { draft in
            SaveAskNoteSheet(
                draft: draft,
                onCancel: { viewModel.handle(.saveAsNoteDismissed) },
                onSubmit: { title in viewModel.handle(.saveAsNoteConfirmed(title)) }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        let hasEvidence = viewModel.hasEvidence
        let isStreaming = viewModel.isStreaming
        let showEmptyState = viewModel.state.messages.isEmpty && hasEvidence

        VStack(spacing: 0) {
            if !hasEvidence {
                AskNoEvidenceBanner(onAddSource: { showAddSourceSheet = true })
                    .padding(.top, 16)
                    .padding(.horizontal, 20)
            }

            if viewModel.state.isLoadingConversation {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = viewModel.state.conversationLoadError {
                Spacer()
                ErrorView(message: error) {
                    viewModel.handle(.retryConversationLoad)
                }
                Spacer()
            } else if showEmptyState {
                ScrollView {
                    AskEmptyStateHeader()
                        .padding(.top, 28)
                    VStack(spacing: 12) {
                        if viewModel.state.isSuggestionsLoading {
                            ForEach(0..<3, id: \.self) { _ in
                                AskSuggestionCardSkeleton()
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(String(localized: "Loading suggestions"))
                        } else {
                            ForEach(viewModel.displaySuggestions, id: \.self) { suggestion in
                                AskSuggestionCard(text: suggestion, enabled: !isStreaming) {
                                    submit(suggestion)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                }
            } else if !viewModel.state.messages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.state.messages) { message in
                                AskMessageBubble(
                                    message: message,
                                    userAvatarLabel: userAvatarLabel,
                                    isSavingNote: viewModel.state.savingMessageID == message.id,
                                    onCitationTap: { citation in viewModel.handle(.citationTap(citation)) },
                                    onStop: { viewModel.handle(.stop) },
                                    onSaveAsNote: { viewModel.handle(.saveAsNoteRequested(message.id)) },
                                    onFeedback: { useful in viewModel.handle(.feedback(message.id, useful: useful)) }
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                    }
                    .onChange(of: viewModel.state.messages.count) { _, count in
                        guard count > 0, let lastID = viewModel.state.messages.last?.id else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            } else {
                Spacer()
            }

            AskInputPanel(
                query: $query,
                hasEvidence: hasEvidence,
                isStreaming: isStreaming,
                scopeChipLabel: viewModel.scopeChipLabel,
                onScopeTap: { showScopeSheet = true },
                onSubmit: { submit(query) }
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 35)
        }
        .id(viewModel.state.conversationEpoch)
    }

    private func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.handle(.submit(trimmed))
        query = ""
    }
}

#Preview {
    FolioAskView(
        viewModel: FolioAskViewModel(
            fetchAskSuggestionsUseCase: PreviewFetchAskSuggestionsUseCase(),
            streamAskAnswerUseCase: PreviewStreamAskAnswerUseCase(),
            fetchAskConversationDetailUseCase: PreviewFetchAskConversationDetailUseCase(),
            sendFeedbackUseCase: PreviewSendFeedbackUseCase(),
            createSavedAnswerNoteUseCase: PreviewCreateSavedAnswerNoteUseCase()
        ),
        sources: FolioDesignFixtures.sources,
        onBackToSpaces: {},
        onOpenSource: { _ in },
        userDisplayName: "Ada Lovelace",
        userEmail: "ada@folio.app"
    )
}

private struct PreviewFetchAskSuggestionsUseCase: FetchAskSuggestionsUseCaseProtocol {
    func execute(spaceId: String, scope: String, sourceId: String?) async throws -> AskSuggestionsResult {
        AskSuggestionsResult(suggestions: [], isDynamic: false)
    }
}

private struct PreviewStreamAskAnswerUseCase: StreamAskAnswerUseCaseProtocol {
    func execute(
        spaceId: String, question: String, scope: AskAnswerScope, sourceId: String?, conversationId: String?
    ) -> AsyncThrowingStream<AskAnswerStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private struct PreviewFetchAskConversationDetailUseCase: FetchAskConversationDetailUseCaseProtocol {
    func execute(spaceId: String, conversationId: String) async throws -> AskConversationDetail {
        AskConversationDetail(
            id: conversationId, researchSpaceId: spaceId, title: "", scope: AskConversationScope(type: "space", sourceId: nil),
            messages: [], createdAt: Date(), updatedAt: Date())
    }
}

private struct PreviewSendFeedbackUseCase: SendFeedbackUseCaseProtocol {
    func execute(spaceId: String, conversationId: String, messageId: String, rating: String) async throws {}
}

private struct PreviewCreateSavedAnswerNoteUseCase: CreateSavedAnswerNoteUseCaseProtocol {
    func execute(
        spaceId: String, title: String, content: String, project: String?,
        originConversationId: String?, originMessageId: String?,
        citationCount: Int?, citations: [SavedAnswerCitationDTO]?
    ) async throws -> Note {
        Note(id: "preview", researchSpaceId: spaceId, title: title, originType: .savedAssistantAnswer,
             content: content, createdAt: Date(), updatedAt: Date(), citationCount: citationCount)
    }
}
