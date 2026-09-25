import SwiftUI

struct MainView: View {
    @StateObject var viewModel: MainViewModel
    let fetchNotesUseCase: any FetchNotesUseCaseProtocol
    let fetchNoteUseCase: any FetchNoteUseCaseProtocol
    let updateNoteUseCase: any UpdateNoteUseCaseProtocol
    let deleteNoteUseCase: any DeleteNoteUseCaseProtocol
    let createNoteUseCase: (any CreateNoteUseCaseProtocol)?
    let convertNoteToSourceUseCase: (any ConvertNoteToSourceUseCaseProtocol)?
    let uploadSourceUseCase: (any UploadSourceUseCaseProtocol)?
    @State private var showAccountSheet = false
    @State private var showSignOutConfirmation = false
    @State private var selectedWorkspace: Workspace?
    @State private var sourceListViewModel: SourceListViewModel?
    @State private var noteListViewModel: NoteListViewModel?
    @State private var notebookViewModel: NotebookViewModel?
    @State private var askConversationListViewModel: AskConversationListViewModel?
    @State private var isAskConversationOpen = false
    @State private var displayedTab: FolioTab = .sources
    @StateObject private var askViewModel: FolioAskViewModel
    private let fetchAskConversationsUseCase: any FetchAskConversationsUseCaseProtocol
    private let deleteConversationUseCase: any DeleteConversationUseCaseProtocol
    private let renameConversationUseCase: any RenameConversationUseCaseProtocol

    init(
        viewModel: MainViewModel,
        fetchNotesUseCase: any FetchNotesUseCaseProtocol,
        fetchNoteUseCase: any FetchNoteUseCaseProtocol,
        updateNoteUseCase: any UpdateNoteUseCaseProtocol,
        deleteNoteUseCase: any DeleteNoteUseCaseProtocol,
        createNoteUseCase: (any CreateNoteUseCaseProtocol)?,
        convertNoteToSourceUseCase: (any ConvertNoteToSourceUseCaseProtocol)?,
        uploadSourceUseCase: (any UploadSourceUseCaseProtocol)?,
        fetchAskSuggestionsUseCase: any FetchAskSuggestionsUseCaseProtocol,
        streamAskAnswerUseCase: any StreamAskAnswerUseCaseProtocol,
        fetchAskConversationsUseCase: any FetchAskConversationsUseCaseProtocol,
        fetchAskConversationDetailUseCase: any FetchAskConversationDetailUseCaseProtocol,
        sendFeedbackUseCase: any SendFeedbackUseCaseProtocol,
        createSavedAnswerNoteUseCase: any CreateSavedAnswerNoteUseCaseProtocol,
        deleteConversationUseCase: any DeleteConversationUseCaseProtocol,
        renameConversationUseCase: any RenameConversationUseCaseProtocol
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.fetchNotesUseCase = fetchNotesUseCase
        self.fetchNoteUseCase = fetchNoteUseCase
        self.updateNoteUseCase = updateNoteUseCase
        self.deleteNoteUseCase = deleteNoteUseCase
        self.createNoteUseCase = createNoteUseCase
        self.convertNoteToSourceUseCase = convertNoteToSourceUseCase
        self.uploadSourceUseCase = uploadSourceUseCase
        self.fetchAskConversationsUseCase = fetchAskConversationsUseCase
        self.deleteConversationUseCase = deleteConversationUseCase
        self.renameConversationUseCase = renameConversationUseCase
        _askViewModel = StateObject(wrappedValue: FolioAskViewModel(
            fetchAskSuggestionsUseCase: fetchAskSuggestionsUseCase,
            streamAskAnswerUseCase: streamAskAnswerUseCase,
            fetchAskConversationDetailUseCase: fetchAskConversationDetailUseCase,
            sendFeedbackUseCase: sendFeedbackUseCase,
            createSavedAnswerNoteUseCase: createSavedAnswerNoteUseCase
        ))
    }
    @StateObject private var keyboardVisibility = KeyboardVisibilityObserver()

    var body: some View {
        ZStack {
            FolioBackdrop()
            content
        }
        .dismissKeyboardOnTapOutside()
        .task { viewModel.handle(.onAppear) }
        .onChange(of: viewModel.state.activeAskScope) { _, scopedSource in
            Task { @MainActor in
                askViewModel.handle(.scopeOptionSelected(sourceID: scopedSource?.id))
            }
        }
        .onChange(of: viewModel.state.isAuthenticated) { _, isAuthenticated in
            guard !isAuthenticated else { return }
            askViewModel.handle(.newConversation)
            askViewModel.updateSources([], spaceId: nil)
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountBottomSheet(
                displayName: viewModel.state.userDisplayName ?? "User",
                emailAddress: viewModel.state.userEmail ?? "Unknown",
                onSignOut: {
                    showAccountSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showSignOutConfirmation = true
                    }
                }
            )
            .presentationDetents([.height(170)])
        }
        .sheet(isPresented: $showSignOutConfirmation) {
            ConfirmationBottomSheet(
                title: String(localized: "Sign out?"),
                message: String(localized: "You will need to sign in again to access your spaces."),
                confirmTitle: String(localized: "Sign Out"),
                onCancel: {
                    showSignOutConfirmation = false
                },
                onConfirm: {
                    showSignOutConfirmation = false
                    completeSignOut()
                }
            )
        }
        .folioToast(message: $viewModel.toastMessage)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.state.isAuthenticated {
            appShellWithTab
        } else {
            FolioLoginView(viewModel: viewModel)
        }
    }

    private var appShellWithTab: some View {
        let showTabBar = viewModel.state.activeReaderID == nil
            && !(viewModel.state.selectedTab == .sources && selectedWorkspace == nil)
        let isKeyboardVisible = keyboardVisibility.isVisible

        return appShell
            .safeAreaInset(edge: .bottom) {
                if Self.shouldShowBottomTabBar(showTabBar: showTabBar, isKeyboardVisible: isKeyboardVisible) {
                    FolioBottomTabBar(selectedTab: displayedTab) { tab in
                        viewModel.handle(.selectTab(tab))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .onChange(of: viewModel.state.selectedTab) { _, newValue in
                displayedTab = newValue
            }
            .onAppear {
                displayedTab = viewModel.state.selectedTab
            }
    }

    static func shouldShowNotebookChrome(selectedTab: FolioTab, isKeyboardVisible: Bool) -> Bool {
        selectedTab == .notebook && !isKeyboardVisible
    }

    static func shouldIgnoreKeyboardSafeArea(
        showTabBar: Bool,
        selectedTab: FolioTab,
        isKeyboardVisible: Bool
    ) -> Bool {
        showTabBar && selectedTab != .notebook && !isKeyboardVisible
    }

    static func shouldShowBottomTabBar(showTabBar: Bool, isKeyboardVisible: Bool) -> Bool {
        showTabBar && !isKeyboardVisible
    }

    @ViewBuilder
    private var appShell: some View {
        let userInitial = viewModel.state.userDisplayName?.first.map(String.init).map { $0.uppercased() } ?? "?"
        if let sourceID = viewModel.state.activeReaderID {
            FolioSourceReaderView(
                sourceID: sourceID,
                fetchSourceDetailUseCase: viewModel.fetchSourceDetailUseCase,
                updateSourceUseCase: viewModel.updateSourceUseCase,
                uploadSourceUseCase: viewModel.uploadSourceUseCase,
                fetchSourcePreviewUseCase: viewModel.fetchSourcePreviewUseCase,
                onBack: {
                    viewModel.handle(.closeReader)
                },
                onAskSource: { source in
                    viewModel.handle(.openAskForSource(source: source, kind: .file))
                },
                onDeleted: { deletedSource in
                    viewModel.handle(.sourceDeleted(source: deletedSource))
                    Task { await sourceListViewModel?.refresh() }
                }
            )
        } else {
            switch viewModel.state.selectedTab {
            case .sources:
                if let workspace = selectedWorkspace, let sourceVM = sourceListViewModel {
                    SourceListView(
                        viewModel: sourceVM,
                        workspaceTitle: workspace.name,
                        onBackToSpaces: { showMySpaces() },
                        onOpenAccountSettings: { showAccountSheet = true },
                        userInitial: currentUserInitial,
                        onSourceOpened: { source in
                            viewModel.handle(.addNewSource(source: source, workspaceID: workspace.id))
                        },
                        onAskSource: { source in
                            viewModel.handle(.openAskForSource(source: source, kind: .file))
                        }
                    )
                } else {
                    WorkspaceListView(
                        viewModel: WorkspaceListViewModel(
                            fetchWorkspaces: viewModel.fetchWorkspacesUseCase,
                            createWorkspace: viewModel.createWorkspaceUseCase,
                            updateWorkspace: viewModel.updateWorkspaceUseCase,
                            deleteWorkspace: viewModel.deleteWorkspaceUseCase
                        ),
                        onSelectWorkspace: { openWorkspace($0) },
                        onWorkspaceCreated: { openWorkspace($0) },
                        onWorkspaceDeleted: { deletedID in
                            if selectedWorkspace?.id == deletedID { selectedWorkspace = nil }
                        },
                        onToast: { viewModel.toastMessage = .success($0) },
                        onOpenAccountSettings: { showAccountSheet = true },
                        userInitial: userInitial
                    )
                }
            case .ask:
                if let workspace = selectedWorkspace,
                    let askListVM = askConversationListViewModel,
                    viewModel.state.activeAskScope == nil,
                    !isAskConversationOpen {
                    AskConversationListView(
                        viewModel: askListVM,
                        workspaceTitle: workspace.name,
                        onBackToSpaces: { showMySpaces() },
                        onNewConversation: {
                            askViewModel.handle(.newConversation)
                            isAskConversationOpen = true
                        },
                        onSelectConversation: { conversation in
                            askViewModel.openExistingConversation(conversation, spaceId: workspace.id)
                            isAskConversationOpen = true
                        }
                    )
                } else {
                    let workspaceSources: [FolioSource] = {
                        if let sourceListViewModel {
                            return sourceListViewModel.state.allSources.map { FolioSource(from: $0, workspaceID: selectedWorkspace?.id) }
                        }
                        return viewModel.state.sources.filter { $0.workspaceID == selectedWorkspace?.id }
                    }()
                    FolioAskView(
                        viewModel: askViewModel,
                        sources: workspaceSources,
                        spaceId: selectedWorkspace?.id,
                        workspaceTitle: selectedWorkspace?.name,
                        onBackToSpaces: {
                            viewModel.handle(.clearAskScope)
                            isAskConversationOpen = false
                            askConversationListViewModel?.handle(.refresh)
                        },
                        onOpenSource: { folioSource in
                            Task {
                                do {
                                    let source = try await viewModel.fetchSourceDetailUseCase.execute(id: folioSource.id)
                                    viewModel.handle(.openReader(source))
                                } catch {
                                    Logger.error("Failed to open source from citation: \(error)")
                                    viewModel.toastMessage = .error(String(localized: "Unable to open source. Please try again."))
                                }
                            }
                        },
                        onSourceAdded: { source in
                            viewModel.handle(.addNewSource(source: source, workspaceID: selectedWorkspace?.id))
                        },
                        uploadSourceUseCase: uploadSourceUseCase,
                        userDisplayName: viewModel.state.userDisplayName,
                        userEmail: viewModel.state.userEmail
                    )
                }
            case .notes:
                if let workspace = selectedWorkspace, let noteVM = noteListViewModel {
                    NoteListView(
                        viewModel: noteVM,
                        workspaceTitle: workspace.name,
                        onBackToSpaces: showMySpaces,
                        onSourceOpened: { sourceID in
                            viewModel.handle(.openSource(id: sourceID, workspaceID: workspace.id))
                        }
                    )
                } else {
                    FolioPlaceholderView(
                        title: String(localized: "Notes"),
                        subtitle: String(localized: "Select a Research Space from Sources to view its notes."),
                        iconName: "note.text",
                        onOpenAccountSettings: { showAccountSheet = true },
                        onBackToSpaces: { showMySpaces() },
                        userInitial: userInitial
                    )
                }
            case .notebook:
                if let vm = notebookViewModel, let workspace = selectedWorkspace {
                    FolioNotebookView(
                        viewModel: vm,
                        noteListViewModel: noteListViewModel,
                        workspaceTitle: workspace.name,
                        onBackToSpaces: { showMySpaces() },
                        onNavigateToNotes: {
                            viewModel.handle(.selectTab(.notes))
                        },
                        onSourceOpened: { sourceID in
                            viewModel.handle(.openSource(id: sourceID, workspaceID: workspace.id))
                        },
                        isKeyboardVisible: keyboardVisibility.isVisible
                    )
                } else {
                    FolioPlaceholderView(
                        title: String(localized: "Notebook"),
                        subtitle: String(localized: "Select a Research Space from Sources to open its notebook."),
                        iconName: "book",
                        onOpenAccountSettings: { showAccountSheet = true },
                        onBackToSpaces: { showMySpaces() },
                        userInitial: userInitial
                    )
                }
            }
        }
    }

    private var currentUserInitial: String {
        viewModel.state.userDisplayName?.first.map(String.init).map { $0.uppercased() } ?? "?"
    }

    private func openWorkspace(_ workspace: Workspace) {
        let sourceVM = SourceListViewModel(
            spaceId: workspace.id,
            fetchSourcesUseCase: viewModel.fetchSourcesUseCase,
            updateSourceUseCase: viewModel.updateSourceUseCase,
            uploadSourceUseCase: viewModel.uploadSourceUseCase
        )
        sourceVM.send(.appeared)
        sourceListViewModel = sourceVM
        let notesViewModel = NoteListViewModel(
            spaceId: workspace.id,
            fetchNotesUseCase: fetchNotesUseCase,
            fetchNoteUseCase: fetchNoteUseCase,
            updateNoteUseCase: updateNoteUseCase,
            deleteNoteUseCase: deleteNoteUseCase,
            createNoteUseCase: createNoteUseCase,
            convertNoteToSourceUseCase: convertNoteToSourceUseCase,
            uploadSourceUseCase: uploadSourceUseCase
        )
        notesViewModel.onSourcesChanged = {
            self.sourceListViewModel?.send(.refresh)
        }
        noteListViewModel = notesViewModel
        askViewModel.onNoteCreated = { [weak notesViewModel] in
            Task { await notesViewModel?.refreshNotes() }
        }
        notebookViewModel = NotebookViewModel(
            fetchNotebookUseCase: viewModel.fetchNotebookUseCase,
            saveNotebookUseCase: viewModel.saveNotebookUseCase
        )
        notebookViewModel?.configure(spaceId: workspace.id, spaceName: workspace.name)
        let askListVM = AskConversationListViewModel(
            spaceId: workspace.id,
            fetchAskConversationsUseCase: fetchAskConversationsUseCase,
            deleteConversationUseCase: deleteConversationUseCase,
            renameConversationUseCase: renameConversationUseCase)
        askConversationListViewModel = askListVM
        askViewModel.onConversationCreated = { [weak askListVM] in
            askListVM?.handle(.refresh)
        }
        isAskConversationOpen = false
        selectedWorkspace = workspace
    }

    private func showMySpaces() {
        notebookViewModel?.flushPendingSave()
        selectedWorkspace = nil
        sourceListViewModel = nil
        noteListViewModel = nil
        notebookViewModel = nil
        askConversationListViewModel = nil
        isAskConversationOpen = false
        viewModel.handle(.showSpaces)
    }

    private func completeSignOut() {
        notebookViewModel?.flushPendingSave()
        selectedWorkspace = nil
        sourceListViewModel = nil
        noteListViewModel = nil
        notebookViewModel = nil
        viewModel.handle(.signOut)
    }
}

#Preview {
    MainView(viewModel: MainViewModel(
        fetchUsersUseCase: PreviewFetchUsersUseCase(),
        fetchMeUseCase: PreviewFetchMeUseCase(),
        getStoredAuthSessionUseCase: PreviewGetStoredAuthSessionUseCase(),
        signUpUseCase: PreviewSignUpUseCase(),
        signInUseCase: PreviewSignInUseCase(),
        signOutUseCase: PreviewSignOutUseCase(),
        refreshTokenUseCase: PreviewRefreshTokenUseCase(),
        fetchWorkspacesUseCase: FetchWorkspacesUseCase(repository: PreviewWorkspaceRepository()),
        createWorkspaceUseCase: CreateWorkspaceUseCase(repository: PreviewWorkspaceRepository()),
        updateWorkspaceUseCase: UpdateWorkspaceUseCase(repository: PreviewWorkspaceRepository()),
        deleteWorkspaceUseCase: DeleteWorkspaceUseCase(repository: PreviewWorkspaceRepository()),
        uploadSourceUseCase: PreviewUploadSourceUseCase(),
        fetchSourcesUseCase: PreviewFetchSourcesUseCase(),
        updateSourceUseCase: PreviewUpdateSourceUseCase(),
        fetchSourceDetailUseCase: PreviewFetchSourceDetailUseCase(),
        fetchSourcePreviewUseCase: PreviewFetchSourcePreviewUseCase(),
        fetchNotebookUseCase: PreviewFetchNotebookUseCase(),
        saveNotebookUseCase: PreviewSaveNotebookUseCase()
    ),
    fetchNotesUseCase: PreviewFetchNotesUseCase(),
    fetchNoteUseCase: PreviewFetchNoteUseCase(),
    updateNoteUseCase: PreviewUpdateNoteUseCase(),
    deleteNoteUseCase: PreviewDeleteNoteUseCase(),
    createNoteUseCase: PreviewCreateNoteUseCase(),
    convertNoteToSourceUseCase: nil,
    uploadSourceUseCase: nil,
    fetchAskSuggestionsUseCase: PreviewFetchAskSuggestionsUseCase(),
    streamAskAnswerUseCase: PreviewStreamAskAnswerUseCase(),
    fetchAskConversationsUseCase: PreviewFetchAskConversationsUseCase(),
    fetchAskConversationDetailUseCase: PreviewFetchAskConversationDetailUseCase(),
    sendFeedbackUseCase: PreviewSendFeedbackUseCase(),
    createSavedAnswerNoteUseCase: PreviewCreateSavedAnswerNoteUseCase(),
    deleteConversationUseCase: PreviewDeleteConversationUseCase(),
    renameConversationUseCase: PreviewRenameConversationUseCase())
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

private struct PreviewFetchAskConversationsUseCase: FetchAskConversationsUseCaseProtocol {
    func execute(query: AskConversationListQuery) async throws -> AskConversationListResult {
        AskConversationListResult(conversations: [], pagination: nil)
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

private struct PreviewDeleteConversationUseCase: DeleteConversationUseCaseProtocol {
    func execute(spaceId: String, conversationId: String) async throws {}
}

private struct PreviewRenameConversationUseCase: RenameConversationUseCaseProtocol {
    func execute(spaceId: String, conversationId: String, title: String) async throws {}
}

final class PreviewWorkspaceRepository: WorkspaceRepositoryProtocol {
    func fetchWorkspaces(query: WorkspaceListQuery) async throws -> WorkspaceListResult {
        WorkspaceListResult(workspaces: [], pagination: nil)
    }
    func createWorkspace(name: String, objective: String) async throws -> Workspace { throw PreviewError.unavailable }
    func updateWorkspace(id: String, name: String, objective: String) async throws -> Workspace { throw PreviewError.unavailable }
    func deleteWorkspace(id: String) async throws { }
}

private struct PreviewFetchUsersUseCase: FetchUsersUseCaseProtocol {
    func execute() async throws -> [User] { [] }
}

private struct PreviewFetchMeUseCase: FetchMeUseCaseProtocol {
    func execute() async throws -> UserIdentity { UserIdentity(name: "Alice", email: "alice@example.com") }
}

private struct PreviewSignUpUseCase: SignUpUseCaseProtocol {
    func execute(name: String, email: String, password: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date())
    }
}

private struct PreviewSignInUseCase: SignInUseCaseProtocol {
    func execute(email: String, password: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date())
    }
}

private struct PreviewSignOutUseCase: SignOutUseCaseProtocol {
    func execute() throws {}
}

private struct PreviewRefreshTokenUseCase: RefreshTokenUseCaseProtocol {
    func execute(refreshToken: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date())
    }
}

private struct PreviewUploadSourceUseCase: UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source {
        Source(id: "preview", researchSpaceId: spaceId, sourceType: .file, title: title ?? "", author: author ?? "", sourceUrl: "", fileName: "", fileSize: 0, fileType: "", pageCount: 0, characterCount: 0, content: "", structuredContent: nil, processingState: .ready, processingError: "", createdAt: Date(), updatedAt: Date())
    }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source {
        Source(id: "preview", researchSpaceId: spaceId, sourceType: .web, title: title ?? "", author: author ?? "", sourceUrl: url, fileName: "", fileSize: 0, fileType: "", pageCount: 0, characterCount: 0, content: "", structuredContent: nil, processingState: .ready, processingError: "", createdAt: Date(), updatedAt: Date())
    }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source {
        Source(id: "preview", researchSpaceId: spaceId, sourceType: .manual, title: title ?? "", author: author ?? "", sourceUrl: "", fileName: "", fileSize: 0, fileType: "", pageCount: 0, characterCount: 0, content: content, structuredContent: nil, processingState: .ready, processingError: "", createdAt: Date(), updatedAt: Date())
    }
    func deleteSource(id: String) async throws {}
    func retrySource(id: String) async throws -> Source {
        Source(id: id, researchSpaceId: "", sourceType: .file, title: "", author: "", sourceUrl: "", fileName: "", fileSize: 0, fileType: "", pageCount: 0, characterCount: 0, content: "", structuredContent: nil, processingState: .added, processingError: "", createdAt: Date(), updatedAt: Date())
    }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private struct PreviewFetchSourcesUseCase: FetchSourcesUseCaseProtocol {
    func execute(query: SourceListQuery) async throws -> SourceListResult {
        SourceListResult(sources: [], pagination: nil)
    }
}

private struct PreviewUpdateSourceUseCase: UpdateSourceUseCaseProtocol {
    func execute(id: String, title: String, author: String, content: String?) async throws -> Source {
        Source(id: id, researchSpaceId: "", sourceType: .file, title: title, author: author, sourceUrl: "", fileName: "", fileSize: 0, fileType: "", pageCount: 0, characterCount: 0, content: content ?? "", structuredContent: nil, processingState: .ready, processingError: "", createdAt: Date(), updatedAt: Date())
    }
}

private struct PreviewFetchSourceDetailUseCase: FetchSourceDetailUseCaseProtocol {
    func execute(id: String) async throws -> Source {
        Source(id: id, researchSpaceId: "", sourceType: .file, title: "", author: "", sourceUrl: "", fileName: "", fileSize: 0, fileType: "", pageCount: 0, characterCount: 0, content: "", structuredContent: nil, processingState: .ready, processingError: "", createdAt: Date(), updatedAt: Date())
    }
}

private struct PreviewFetchSourcePreviewUseCase: FetchSourcePreviewUseCaseProtocol {
    func execute(source: Source) async throws -> SourcePreview {
        SourcePreview(url: "https://example.com/preview.pdf")
    }
}

private struct PreviewFetchNotesUseCase: FetchNotesUseCaseProtocol { func execute(query: NoteListQuery) async throws -> NoteListResult { NoteListResult(notes: [], pagination: nil) } }
private struct PreviewFetchNoteUseCase: FetchNoteUseCaseProtocol { func execute(spaceId: String, noteId: String) async throws -> Note { throw PreviewError.unavailable } }
private struct PreviewUpdateNoteUseCase: UpdateNoteUseCaseProtocol { func execute(spaceId: String, noteId: String, title: String, content: String) async throws -> Note { throw PreviewError.unavailable } }
private struct PreviewDeleteNoteUseCase: DeleteNoteUseCaseProtocol { func execute(spaceId: String, noteId: String) async throws {} }
private struct PreviewCreateNoteUseCase: CreateNoteUseCaseProtocol { func execute(spaceId: String, title: String, content: String) async throws -> Note { throw PreviewError.unavailable } }

private struct PreviewFetchNotebookUseCase: FetchNotebookUseCaseProtocol {
    func execute(spaceId: String) async throws -> NotebookFetchResult {
        NotebookFetchResult(
            entry: NotebookEntry(id: "", researchSpaceId: spaceId, content: "", createdAt: Date(), updatedAt: Date()),
            preservedOfflineDraft: false)
    }
}

private struct PreviewSaveNotebookUseCase: SaveNotebookUseCaseProtocol {
    func execute(entry: NotebookEntry) async throws {}
}
