import Foundation
import Combine

@MainActor
final class MainViewModel: ViewModelProtocol {
    struct State: Equatable {
        var isAuthenticated = false
        var selectedTab: FolioTab = .sources
        var sourcesMode: FolioSourcesMode = .spaces
        var selectedFilter: FolioSourceFilter = .all
        var activeReaderID: String?
        var activeAskScope: Source?
        var sourceFilters: [FolioSourceFilter] = []
        var sources: [FolioSource] = []
        var authLoading = false
        var userDisplayName: String?
        var userEmail: String?
    }

    @Published var toastMessage: ToastMessage? = nil

    enum Action {
        case onAppear
        case signIn(email: String, password: String)
        case signUp(name: String, email: String, password: String)
        case signInWithApple
        case signOut
        case selectTab(FolioTab)
        case showSpaces
        case showLibrary
        case selectFilter(FolioSourceFilter)
        case openReader(Source)
        case closeReader
        case dismissToast
        case addNewSource(source: Source, workspaceID: String?)
        case openSource(id: String, workspaceID: String)
        case sourceDeleted(source: Source)
        case openAskForSource(source: Source, kind: FolioSourceKind)
        case clearAskScope
    }

    private let fetchUsersUseCase: any FetchUsersUseCaseProtocol
    private let fetchMeUseCase: any FetchMeUseCaseProtocol
    private let getStoredAuthSessionUseCase: any GetStoredAuthSessionUseCaseProtocol
    private let signUpUseCase: any SignUpUseCaseProtocol
    private let signInUseCase: any SignInUseCaseProtocol
    private let signOutUseCase: any SignOutUseCaseProtocol
    private let refreshTokenUseCase: any RefreshTokenUseCaseProtocol
    let passwordResetUseCase: any RequestPasswordResetUseCaseProtocol
    let fetchWorkspacesUseCase: any FetchWorkspacesUseCaseProtocol
    let createWorkspaceUseCase: any CreateWorkspaceUseCaseProtocol
    let updateWorkspaceUseCase: any UpdateWorkspaceUseCaseProtocol
    let deleteWorkspaceUseCase: any DeleteWorkspaceUseCaseProtocol
    let uploadSourceUseCase: any UploadSourceUseCaseProtocol
    let fetchSourcesUseCase: any FetchSourcesUseCaseProtocol
    let updateSourceUseCase: any UpdateSourceUseCaseProtocol
    let fetchNotebookUseCase: any FetchNotebookUseCaseProtocol
    let saveNotebookUseCase: any SaveNotebookUseCaseProtocol
    private var profileRequestGeneration = 0
    private var sessionGeneration = 0
    private var signOutTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var refreshTaskID: UUID?
    let fetchSourceDetailUseCase: any FetchSourceDetailUseCaseProtocol
    let fetchSourcePreviewUseCase: any FetchSourcePreviewUseCaseProtocol

    init(
        fetchUsersUseCase: any FetchUsersUseCaseProtocol,
        fetchMeUseCase: any FetchMeUseCaseProtocol,
        getStoredAuthSessionUseCase: any GetStoredAuthSessionUseCaseProtocol,
        signUpUseCase: any SignUpUseCaseProtocol,
        signInUseCase: any SignInUseCaseProtocol,
        signOutUseCase: any SignOutUseCaseProtocol,
        refreshTokenUseCase: any RefreshTokenUseCaseProtocol,
        passwordResetUseCase: any RequestPasswordResetUseCaseProtocol,
        fetchWorkspacesUseCase: any FetchWorkspacesUseCaseProtocol,
        createWorkspaceUseCase: any CreateWorkspaceUseCaseProtocol,
        updateWorkspaceUseCase: any UpdateWorkspaceUseCaseProtocol,
        deleteWorkspaceUseCase: any DeleteWorkspaceUseCaseProtocol,
        uploadSourceUseCase: any UploadSourceUseCaseProtocol,
        fetchSourcesUseCase: any FetchSourcesUseCaseProtocol,
        updateSourceUseCase: any UpdateSourceUseCaseProtocol,
        fetchSourceDetailUseCase: any FetchSourceDetailUseCaseProtocol,
        fetchSourcePreviewUseCase: any FetchSourcePreviewUseCaseProtocol,
        fetchNotebookUseCase: any FetchNotebookUseCaseProtocol,
        saveNotebookUseCase: any SaveNotebookUseCaseProtocol,
        initialSources: [FolioSource] = []
    ) {
        self.fetchUsersUseCase = fetchUsersUseCase
        self.fetchMeUseCase = fetchMeUseCase
        self.getStoredAuthSessionUseCase = getStoredAuthSessionUseCase
        self.signUpUseCase = signUpUseCase
        self.signInUseCase = signInUseCase
        self.signOutUseCase = signOutUseCase
        self.refreshTokenUseCase = refreshTokenUseCase
        self.passwordResetUseCase = passwordResetUseCase
        self.fetchWorkspacesUseCase = fetchWorkspacesUseCase
        self.createWorkspaceUseCase = createWorkspaceUseCase
        self.updateWorkspaceUseCase = updateWorkspaceUseCase
        self.deleteWorkspaceUseCase = deleteWorkspaceUseCase
        self.uploadSourceUseCase = uploadSourceUseCase
        self.fetchSourcesUseCase = fetchSourcesUseCase
        self.updateSourceUseCase = updateSourceUseCase
        self.fetchSourceDetailUseCase = fetchSourceDetailUseCase
        self.fetchSourcePreviewUseCase = fetchSourcePreviewUseCase
        self.fetchNotebookUseCase = fetchNotebookUseCase
        self.saveNotebookUseCase = saveNotebookUseCase
        state.sources = initialSources
        if let token = getStoredAuthSessionUseCase.execute() {
            state.isAuthenticated = token.isValid || !token.refreshToken.isEmpty
        }
#if DEBUG
        if initialSources.isEmpty {
            state.sourceFilters = FolioDesignFixtures.filters
            state.sources = FolioDesignFixtures.sources
        }
#endif
    }

    @Published private(set) var state: State = .init()

    var visibleSources: [FolioSource] {
        visibleSources(inWorkspaceID: nil)
    }

    func visibleSources(inWorkspaceID workspaceID: String?) -> [FolioSource] {
        state.sources.filter { source in
            guard workspaceID == nil || source.workspaceID == workspaceID else { return false }
            switch state.selectedFilter {
            case .all:
                return true
            case .files:
                return source.kind == .file
            case .web:
                return source.kind == .web
            case .text:
                return source.kind == .text
            }
        }
    }

    func handle(_ action: Action) {
        switch action {
        case .onAppear:
            checkSession()
        case .signIn(let email, let password):
            Task { await performSignIn(email: email, password: password) }
        case .signUp(let name, let email, let password):
            Task { await performSignUp(name: name, email: email, password: password) }
        case .signInWithApple:
#if DEBUG
            state.isAuthenticated = true
            state.selectedTab = .sources
            state.sourcesMode = .spaces
            state.activeReaderID = nil
#endif
        case .signOut:
            guard signOutTask == nil else { return }
            sessionGeneration += 1
            let refreshTask = self.refreshTask
            refreshTask?.cancel()
            signOutTask = Task { [weak self] in
                guard let self else { return }
                await refreshTask?.value
                do {
                    try await signOutUseCase.executeAwaitingCancellation()
                } catch let error as AuthError {
                    toastMessage = .error(error.errorDescription ?? error.localizedDescription)
                    signOutTask = nil
                    return
                } catch {
                    Logger.error("Sign-out failed: \(error)")
                    toastMessage = .error(String(localized: "Unable to sign out securely. Please try again."))
                    signOutTask = nil
                    return
                }
                invalidateProfileRequest()
                state.isAuthenticated = false
                state.userDisplayName = nil
                state.userEmail = nil
                state.selectedTab = .sources
                state.sourcesMode = .spaces
                state.activeReaderID = nil
                toastMessage = .success(String(localized: "Signed out successfully"))
                signOutTask = nil
            }
        case .selectTab(let tab):
            state.selectedTab = tab
            state.activeReaderID = nil
            if tab != .ask {
                state.activeAskScope = nil
            }
            state.sourcesMode = .spaces
        case .showSpaces:
            state.selectedTab = .sources
            state.sourcesMode = .spaces
            state.activeReaderID = nil
            state.activeAskScope = nil
        case .showLibrary:
            state.selectedTab = .sources
            state.sourcesMode = .library
            state.activeReaderID = nil
            state.activeAskScope = nil
        case .selectFilter(let filter):
            state.selectedFilter = filter
        case .openReader(let source):
            state.activeReaderID = source.id
            state.activeAskScope = nil
            state.selectedTab = .sources
            state.sourcesMode = .library
        case .closeReader:
            state.activeReaderID = nil
        case .dismissToast:
            toastMessage = nil
        case .addNewSource(let source, let workspaceID):
            let folioSource = FolioSource(from: source, workspaceID: workspaceID)
            if let index = state.sources.firstIndex(where: { $0.id == source.id }) {
                state.sources[index] = folioSource
            } else {
                state.sources.append(folioSource)
            }
            state.activeReaderID = source.id
            state.activeAskScope = nil
        case .openSource(let id, _):
            state.activeReaderID = id
        case .sourceDeleted(let source):
            state.sources.removeAll { $0.id == source.id }
            state.activeReaderID = nil
            state.activeAskScope = nil
            toastMessage = .success(String(localized: "Source deleted"))
        case .openAskForSource(let source, _):
            if let index = state.sources.firstIndex(where: { $0.id == source.id }) {
                let existing = state.sources[index]
                state.sources[index] = FolioSource(from: source, workspaceID: existing.workspaceID)
            } else {
                state.sources.append(FolioSource(from: source, workspaceID: nil))
            }
            state.selectedTab = .ask
            state.activeReaderID = nil
            state.activeAskScope = source
            state.sourcesMode = .spaces
        case .clearAskScope:
            state.activeAskScope = nil
        }
    }

    private func performSignIn(email: String, password: String) async {
        guard !state.authLoading else { return }
        state.authLoading = true
        defer { state.authLoading = false }
        sessionGeneration += 1
        refreshTask?.cancel()
        await refreshTask?.value
        await signOutTask?.value
        do {
            let token = try await signInUseCase.execute(email: email, password: password)
            applySession(token)
        } catch let error as AuthError {
            toastMessage = .error(error.errorDescription ?? error.localizedDescription)
        } catch {
            Logger.error("Sign-in failed: \(error)")
            toastMessage = .error(String(localized: "Unable to connect. Please check your internet and try again."))
        }
    }

    private func performSignUp(name: String, email: String, password: String) async {
        guard !state.authLoading else { return }
        state.authLoading = true
        defer { state.authLoading = false }
        sessionGeneration += 1
        refreshTask?.cancel()
        await refreshTask?.value
        await signOutTask?.value
        do {
            let token = try await signUpUseCase.execute(name: name, email: email, password: password)
            applySession(token)
        } catch let error as AuthError {
            toastMessage = .error(error.errorDescription ?? error.localizedDescription)
        } catch {
            Logger.error("Sign-up failed: \(error)")
            toastMessage = .error(String(localized: "Unable to connect. Please check your internet and try again."))
        }
    }

    private func applySession(_ token: AuthToken) {
        state.isAuthenticated = true
        state.userDisplayName = nil
        state.userEmail = nil
        state.selectedTab = .sources
        state.sourcesMode = .spaces
        state.activeReaderID = nil
        startProfileFetch()
    }

    private func loadUsers() async {
        do {
            let users = try await fetchUsersUseCase.execute()
            state.sources = users.map { user in
                FolioSource(
                    id: "\(user.id)",
                    workspaceID: nil,
                    kind: .web,
                    title: user.name,
                    subtitle: user.email,
                    addedText: "Added just now",
                    status: .ready,
                    chapterTitle: "",
                    chapterText: user.email,
                    calloutText: "",
                    citationTitle: "",
                    citationDetail: user.name,
                    citationText: "",
                    pageLabel: "\(user.id)"
                )
            }
            Logger.debug("Fetched \(users.count) users")
        } catch {
            Logger.error("Failed to load users: \(error)")
        }
    }

    private func startProfileFetch() {
        profileRequestGeneration += 1
        let requestGeneration = profileRequestGeneration
        Task { [weak self] in
            await self?.fetchMe(requestGeneration: requestGeneration)
        }
    }

    private func invalidateProfileRequest() {
        profileRequestGeneration += 1
    }

    private func fetchMe(requestGeneration: Int) async {
        do {
            let identity = try await fetchMeUseCase.execute()
            guard requestGeneration == profileRequestGeneration, state.isAuthenticated else { return }
            state.userDisplayName = identity.name
            state.userEmail = identity.email
        } catch {
            guard requestGeneration == profileRequestGeneration, state.isAuthenticated else { return }
            Logger.error("Failed to fetch user profile: \(error)")
            state.userDisplayName = "User"
            state.userEmail = "Unknown"
        }
    }

    private func checkSession() {
        guard refreshTask == nil, signOutTask == nil, !state.authLoading else { return }
        guard let token = getStoredAuthSessionUseCase.execute() else { return }
        if token.isValid {
            state.isAuthenticated = true
            startProfileFetch()
            return
        }
        sessionGeneration += 1
        let generation = sessionGeneration
        let taskID = UUID()
        refreshTaskID = taskID
        refreshTask = Task {
            await attemptTokenRefresh(token, generation: generation)
            guard refreshTaskID == taskID else { return }
            refreshTask = nil
            refreshTaskID = nil
        }
    }

    private func attemptTokenRefresh(_ token: AuthToken, generation: Int) async {
        guard !token.refreshToken.isEmpty else { return }
        do {
            let newToken = try await refreshTokenUseCase.execute(refreshToken: token.refreshToken)
            guard generation == sessionGeneration else { return }
            applySession(newToken)
        } catch {
            guard generation == sessionGeneration else { return }
            do {
                try await signOutUseCase.executeAwaitingCancellation()
            } catch {
                Logger.error("Failed to clear expired session: \(error)")
            }
            invalidateProfileRequest()
            state.isAuthenticated = false
            state.userDisplayName = nil
            state.userEmail = nil
        }
    }
}
