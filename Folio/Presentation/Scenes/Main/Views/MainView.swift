import SwiftUI

struct MainView: View {
    @StateObject var viewModel: MainViewModel
    @State private var showAccountSettings = false
    @State private var selectedWorkspace: Workspace?

    var body: some View {
        ZStack {
            FolioBackdrop()
            content
        }
        .task { viewModel.handle(.onAppear) }
        .fullScreenCover(isPresented: $showAccountSettings) {
            FolioBackdrop()
                .overlay {
                    FolioAccountSettingsView(
                        displayName: viewModel.state.userDisplayName ?? "User",
                        emailAddress: viewModel.state.userEmail ?? "",
                        onSignOut: {
                            showAccountSettings = false
                            viewModel.handle(.signOut)
                        }
                    )
                }
                .folioToast(message: $viewModel.toastMessage)
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
        appShell
            .safeAreaInset(edge: .bottom) {
                let isMySpaces = viewModel.state.selectedTab == .sources
                    && viewModel.state.sourcesMode == .spaces
                    && selectedWorkspace == nil
                if viewModel.state.activeReader == nil && !isMySpaces {
                    FolioBottomTabBar(selectedTab: viewModel.state.selectedTab) { tab in
                        selectedWorkspace = nil
                        viewModel.handle(.selectTab(tab))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
    }

    @ViewBuilder
    private var appShell: some View {
        let userInitial = viewModel.state.userDisplayName?.first.map(String.init).map { $0.uppercased() } ?? "?"
        switch viewModel.state.activeReader {
        case .some(let source):
            FolioSourceReaderView(source: source, onBack: {
                viewModel.handle(.closeReader)
            }, onOpenAccountSettings: { showAccountSettings = true }, userInitial: userInitial)
        case .none:
            if selectedWorkspace != nil {
                FolioSourcesView(
                    workspaceID: selectedWorkspace?.id,
                    workspaceTitle: selectedWorkspace?.name,
                    filters: viewModel.state.sourceFilters,
                    selectedFilter: viewModel.state.selectedFilter,
                    sources: viewModel.visibleSources(inWorkspaceID: selectedWorkspace?.id),
                    onSelectFilter: { viewModel.handle(.selectFilter($0)) },
                    onSelectSource: { viewModel.handle(.openReader($0)) },
                    onSearch: {},
                    onMenu: {},
                    onOpenAccountSettings: { showAccountSettings = true },
                    onBackToSpaces: { showMySpaces() },
                    userInitial: currentUserInitial
                )
            } else {
                switch viewModel.state.selectedTab {
                case .sources:
                    if viewModel.state.sourcesMode == .spaces {
                        WorkspaceListView(
                            viewModel: WorkspaceListViewModel(repository: viewModel.workspaceRepository),
                            onSelectWorkspace: { selectedWorkspace = $0 },
                            onWorkspaceCreated: { selectedWorkspace = $0 },
                            onWorkspaceDeleted: { deletedID in
                                if selectedWorkspace?.id == deletedID { selectedWorkspace = nil }
                            },
                            onToast: { viewModel.toastMessage = .success($0) },
                            onOpenAccountSettings: { showAccountSettings = true },
                            userInitial: userInitial
                        )
                    } else {
                        FolioSourcesView(
                            filters: viewModel.state.sourceFilters,
                            selectedFilter: viewModel.state.selectedFilter,
                            sources: viewModel.visibleSources,
                            onSelectFilter: { viewModel.handle(.selectFilter($0)) },
                            onSelectSource: { viewModel.handle(.openReader($0)) },
                            onSearch: {},
                            onMenu: {},
                            onOpenAccountSettings: { showAccountSettings = true },
                            onBackToSpaces: { showMySpaces() },
                            userInitial: userInitial
                        )
                    }
                case .ask:
                    FolioAskView(onOpenAccountSettings: { showAccountSettings = true }, onBackToSpaces: { showMySpaces() }, userInitial: userInitial)
                case .notes:
                    FolioPlaceholderView(
                        title: "Notes",
                        subtitle: "Capture claims, quotes, and follow-up ideas in one private space.",
                        iconName: "note.text",
                        onOpenAccountSettings: { showAccountSettings = true },
                        onBackToSpaces: { showMySpaces() },
                        userInitial: userInitial
                    )
                case .notebook:
                    FolioPlaceholderView(
                        title: "Notebook",
                        subtitle: "Organize drafts, syntheses, and research threads here.",
                        iconName: "book",
                        onOpenAccountSettings: { showAccountSettings = true },
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

    private func showMySpaces() {
        selectedWorkspace = nil
        viewModel.handle(.showSpaces)
    }
}

#Preview {
    MainView(viewModel: MainViewModel(
        fetchUsersUseCase: PreviewFetchUsersUseCase(),
        localStorage: UserDefaultsStorage(),
        signUpUseCase: PreviewSignUpUseCase(),
        signInUseCase: PreviewSignInUseCase(),
        signOutUseCase: PreviewSignOutUseCase(),
        refreshTokenUseCase: PreviewRefreshTokenUseCase(),
        workspaceRepository: PreviewWorkspaceRepository()
    ))
}

final class PreviewWorkspaceRepository: WorkspaceRepositoryProtocol {
    func fetchWorkspaces(query: WorkspaceListQuery) async throws -> WorkspaceListResult {
        WorkspaceListResult(workspaces: [], pagination: nil)
    }
    func createWorkspace(name: String, objective: String) async throws -> Workspace { fatalError("Preview only") }
    func updateWorkspace(id: String, name: String, objective: String) async throws -> Workspace { fatalError("Preview only") }
    func deleteWorkspace(id: String) async throws { }
}

private struct PreviewFetchUsersUseCase: FetchUsersUseCaseProtocol {
    func execute() async throws -> [User] { [] }
}

private struct PreviewSignUpUseCase: SignUpUseCaseProtocol {
    func execute(name: String, email: String, password: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date(), userName: nil, userEmail: nil)
    }
}

private struct PreviewSignInUseCase: SignInUseCaseProtocol {
    func execute(email: String, password: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date(), userName: nil, userEmail: nil)
    }
}

private struct PreviewSignOutUseCase: SignOutUseCaseProtocol {
    func execute() {}
}

private struct PreviewRefreshTokenUseCase: RefreshTokenUseCaseProtocol {
    func execute(refreshToken: String) async throws -> AuthToken {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date(), userName: nil, userEmail: nil)
    }
}
