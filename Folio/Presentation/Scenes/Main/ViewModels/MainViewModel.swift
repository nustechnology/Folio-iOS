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
        case addNewSource(source: Source, workspaceID: String?)
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
    let fetchSourcesUseCase: any FetchSourcesUseCaseProtocol
    let updateSourceUseCase: any UpdateSourceUseCaseProtocol

    init(
        fetchUsersUseCase: any FetchUsersUseCaseProtocol,
        localStorage: LocalStorageProtocol,
        signUpUseCase: any SignUpUseCaseProtocol,
        signInUseCase: any SignInUseCaseProtocol,
        signOutUseCase: any SignOutUseCaseProtocol,
        refreshTokenUseCase: any RefreshTokenUseCaseProtocol,
        workspaceRepository: WorkspaceRepositoryProtocol,
        uploadSourceUseCase: any UploadSourceUseCaseProtocol,
        fetchSourcesUseCase: any FetchSourcesUseCaseProtocol,
        updateSourceUseCase: any UpdateSourceUseCaseProtocol,
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
        self.fetchSourcesUseCase = fetchSourcesUseCase
        self.updateSourceUseCase = updateSourceUseCase
        state.sources = initialSources
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
            state.sourcesMode = .spaces
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
        case .addNewSource(let source, let workspaceID):
            let folioSource = FolioSource(from: source, workspaceID: workspaceID)
            if let index = state.sources.firstIndex(where: { $0.id == source.id }) {
                state.sources[index] = folioSource
            } else {
                state.sources.append(folioSource)
            }
            state.activeReader = folioSource
        case .openAskForSource(let source, _):
            if let index = state.sources.firstIndex(where: { $0.id == source.id }) {
                let existing = state.sources[index]
                state.sources[index] = FolioSource(from: source, workspaceID: existing.workspaceID)
            } else {
                state.sources.append(FolioSource(from: source, workspaceID: nil))
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
