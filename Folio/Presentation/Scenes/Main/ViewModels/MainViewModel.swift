import Foundation
import Combine

@MainActor
final class MainViewModel: ViewModelProtocol {
    struct State: Equatable {
        var isAuthenticated = false
        var selectedTab: FolioTab = .sources
        var sourcesMode: FolioSourcesMode = .spaces
        var selectedFilter: FolioSourceFilter = .all
        var activeReader: FolioSource?
        var spaces: [FolioSpace] = []
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
        case openReader(FolioSource)
        case closeReader
        case dismissToast
        case addNewSource(source: Source, kind: FolioSourceKind, workspaceID: String?)
        case openAskForSource(source: Source, kind: FolioSourceKind)
    }

    private let fetchUsersUseCase: any FetchUsersUseCaseProtocol
    private let localStorage: LocalStorageProtocol
    private let signUpUseCase: any SignUpUseCaseProtocol
    private let signInUseCase: any SignInUseCaseProtocol
    private let signOutUseCase: any SignOutUseCaseProtocol
    private let refreshTokenUseCase: any RefreshTokenUseCaseProtocol
    let workspaceRepository: WorkspaceRepositoryProtocol
    let uploadSourceUseCase: any UploadSourceUseCaseProtocol

    init(
        fetchUsersUseCase: any FetchUsersUseCaseProtocol,
        localStorage: LocalStorageProtocol,
        signUpUseCase: any SignUpUseCaseProtocol,
        signInUseCase: any SignInUseCaseProtocol,
        signOutUseCase: any SignOutUseCaseProtocol,
        refreshTokenUseCase: any RefreshTokenUseCaseProtocol,
        workspaceRepository: WorkspaceRepositoryProtocol,
        uploadSourceUseCase: any UploadSourceUseCaseProtocol,
        initialSources: [FolioSource] = []
    ) {
        self.fetchUsersUseCase = fetchUsersUseCase
        self.localStorage = localStorage
        self.signUpUseCase = signUpUseCase
        self.signInUseCase = signInUseCase
        self.signOutUseCase = signOutUseCase
        self.refreshTokenUseCase = refreshTokenUseCase
        self.workspaceRepository = workspaceRepository
        self.uploadSourceUseCase = uploadSourceUseCase
        state.sources = initialSources
#if DEBUG
        if initialSources.isEmpty {
            state.spaces = FolioDesignFixtures.spaces
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
            case .papers:
                return source.kind == .paper
            case .books:
                return source.kind == .book
            case .web:
                return source.kind == .web
            }
        }
    }

    func handle(_ action: Action) {
        switch action {
        case .onAppear:
            checkSession()
            if state.isAuthenticated {
                state.spaces = FolioDesignFixtures.spaces
                state.sourceFilters = [.all, .papers, .books, .web]
                Task { await loadUsers() }
            }
        case .signIn(let email, let password):
            Task { await performSignIn(email: email, password: password) }
        case .signUp(let name, let email, let password):
            Task { await performSignUp(name: name, email: email, password: password) }
        case .signInWithApple:
#if DEBUG
            state.isAuthenticated = true
            state.selectedTab = .sources
            state.sourcesMode = .spaces
            state.activeReader = nil
#endif
        case .signOut:
            signOutUseCase.execute()
            state.isAuthenticated = false
            state.userDisplayName = nil
            state.userEmail = nil
            state.selectedTab = .sources
            state.sourcesMode = .spaces
            state.activeReader = nil
        case .selectTab(let tab):
            state.selectedTab = tab
            state.activeReader = nil
            state.sourcesMode = tab == .sources ? .library : .spaces
        case .showSpaces:
            state.selectedTab = .sources
            state.sourcesMode = .spaces
            state.activeReader = nil
        case .showLibrary:
            state.selectedTab = .sources
            state.sourcesMode = .library
            state.activeReader = nil
        case .selectFilter(let filter):
            state.selectedFilter = filter
        case .openReader(let source):
            state.activeReader = source
            state.selectedTab = .sources
            state.sourcesMode = .library
        case .closeReader:
            state.activeReader = nil
        case .dismissToast:
            toastMessage = nil
        case .addNewSource(let source, let kind, let workspaceID):
            let folioSource = FolioSource(from: source, workspaceID: workspaceID, kind: kind)
            if let index = state.sources.firstIndex(where: { $0.id == source.id }) {
                state.sources[index] = folioSource
            } else {
                state.sources.append(folioSource)
            }
            state.activeReader = folioSource
        case .openAskForSource(let source, let kind):
            if let index = state.sources.firstIndex(where: { $0.id == source.id }) {
                let existing = state.sources[index]
                state.sources[index] = FolioSource(from: source, workspaceID: existing.workspaceID, kind: kind)
            } else {
                state.sources.append(FolioSource(from: source, workspaceID: nil, kind: kind))
            }
            state.selectedTab = .ask
            state.activeReader = nil
            state.sourcesMode = .spaces
        }
    }

    private func performSignIn(email: String, password: String) async {
        state.authLoading = true
        do {
            let token = try await signInUseCase.execute(email: email, password: password)
            applySession(token)
        } catch let error as AuthError {
            toastMessage = .error(error.errorDescription ?? error.localizedDescription)
        } catch {
            Logger.error("Sign-in failed: \(error)")
            toastMessage = .error(String(localized: "Unable to connect. Please check your internet and try again."))
        }
        state.authLoading = false
    }

    private func performSignUp(name: String, email: String, password: String) async {
        state.authLoading = true
        do {
            let token = try await signUpUseCase.execute(name: name, email: email, password: password)
            applySession(token)
        } catch let error as AuthError {
            toastMessage = .error(error.errorDescription ?? error.localizedDescription)
        } catch {
            Logger.error("Sign-up failed: \(error)")
            toastMessage = .error(String(localized: "Unable to connect. Please check your internet and try again."))
        }
        state.authLoading = false
    }

    private func applySession(_ token: AuthToken) {
        state.isAuthenticated = true
        state.userDisplayName = token.userName
        state.userEmail = token.userEmail
        state.selectedTab = .sources
        state.sourcesMode = .spaces
        state.activeReader = nil
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

    private func checkSession() {
        guard let dto: AuthTokenDTO = try? localStorage.load(forKey: StorageKey.authSession) else { return }
        let token = dto.toDomain()
        if token.isValid {
            state.isAuthenticated = true
            state.userDisplayName = token.userName
            state.userEmail = token.userEmail
            return
        }
        Task { await attemptTokenRefresh(token) }
    }

    private func attemptTokenRefresh(_ token: AuthToken) async {
        guard !token.refreshToken.isEmpty else { return }
        do {
            let newToken = try await refreshTokenUseCase.execute(refreshToken: token.refreshToken)
            applySession(newToken)
        } catch {
            signOutUseCase.execute()
            state.isAuthenticated = false
            state.userDisplayName = nil
            state.userEmail = nil
        }
    }
}
