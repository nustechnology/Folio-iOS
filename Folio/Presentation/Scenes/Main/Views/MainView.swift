import SwiftUI

struct MainView: View {
    @StateObject var viewModel: MainViewModel
    @State private var showAccountSettings = false

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
                if viewModel.state.activeReader == nil {
                    FolioBottomTabBar(selectedTab: viewModel.state.selectedTab) { tab in
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
            switch viewModel.state.selectedTab {
            case .sources:
                if viewModel.state.sourcesMode == .spaces {
                    FolioSpacesView(
                        spaces: viewModel.state.spaces,
                        onSelectSources: { viewModel.handle(.showLibrary) },
                        onSelectAsk: { viewModel.handle(.selectTab(.ask)) },
                        onSearch: {},
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
                        userInitial: userInitial
                    )
                }
            case .ask:
                FolioAskView(onOpenAccountSettings: { showAccountSettings = true }, userInitial: userInitial)
            case .notes:
                FolioPlaceholderView(
                    title: "Notes",
                    subtitle: "Capture claims, quotes, and follow-up ideas in one private space.",
                    iconName: "note.text",
                    onOpenAccountSettings: { showAccountSettings = true },
                    userInitial: userInitial
                )
            case .notebook:
                FolioPlaceholderView(
                    title: "Notebook",
                    subtitle: "Organize drafts, syntheses, and research threads here.",
                    iconName: "book",
                    onOpenAccountSettings: { showAccountSettings = true },
                    userInitial: userInitial
                )
            }
        }
    }
}

#Preview {
    MainView(viewModel: MainViewModel(
        fetchUsersUseCase: PreviewFetchUsersUseCase(),
        localStorage: UserDefaultsStorage(),
        signUpUseCase: PreviewSignUpUseCase(),
        signInUseCase: PreviewSignInUseCase(),
        signOutUseCase: PreviewSignOutUseCase(),
        refreshTokenUseCase: PreviewRefreshTokenUseCase()
    ))
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
