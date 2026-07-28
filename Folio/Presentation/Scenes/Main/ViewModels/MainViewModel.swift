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
    }

    enum Action {
        case onAppear
        case signIn(FolioCredential)
        case signInWithApple
        case signOut
        case selectTab(FolioTab)
        case showLibrary
        case selectFilter(FolioSourceFilter)
        case openReader(FolioSource)
        case closeReader
    }

    private let fetchUsersUseCase: any FetchUsersUseCaseProtocol
    private let localStorage: LocalStorageProtocol

    init(fetchUsersUseCase: any FetchUsersUseCaseProtocol, localStorage: LocalStorageProtocol) {
        self.fetchUsersUseCase = fetchUsersUseCase
        self.localStorage = localStorage
#if DEBUG
        state.spaces = FolioDesignFixtures.spaces
        state.sourceFilters = FolioDesignFixtures.filters
        state.sources = FolioDesignFixtures.sources
#endif
    }

    @Published private(set) var state: State = .init()

    var visibleSources: [FolioSource] {
        state.sources.filter { source in
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
        case .signIn(let credential):
#if DEBUG
            guard !credential.email.isEmpty, !credential.password.isEmpty else { return }
            saveSession()
            state.isAuthenticated = true
            state.selectedTab = .sources
            state.sourcesMode = .spaces
            state.activeReader = nil
#endif
        case .signInWithApple:
#if DEBUG
            saveSession()
            state.isAuthenticated = true
            state.selectedTab = .sources
            state.sourcesMode = .spaces
            state.activeReader = nil
#endif
        case .signOut:
            localStorage.remove(forKey: "auth_session")
            state.isAuthenticated = false
            state.selectedTab = .sources
            state.sourcesMode = .spaces
            state.activeReader = nil
        case .selectTab(let tab):
            state.selectedTab = tab
            state.activeReader = nil
            state.sourcesMode = .spaces
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
        }
    }

    private func loadUsers() async {
        do {
            let users = try await fetchUsersUseCase.execute()
            state.sources = users.map { user in
                FolioSource(
                    id: "\(user.id)",
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
        guard let session: AuthSession = try? localStorage.load(forKey: "auth_session"),
              session.isValid else { return }
        state.isAuthenticated = true
    }

    private func saveSession() {
        let session = AuthSession(
            token: UUID().uuidString,
            expiresAt: Date().addingTimeInterval(86400)
        )
        try? localStorage.save(session, forKey: "auth_session")
    }
}
