import SwiftUI

struct MainView: View {
    @StateObject var viewModel: MainViewModel

    var body: some View {
        ZStack {
            FolioBackdrop()
            content
        }
        .task { viewModel.handle(.onAppear) }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.state.isAuthenticated {
            appShellWithTab
        } else {
            FolioLoginView(
                onSignIn: { credential in
                    viewModel.handle(.signIn(credential))
                },
                onSignInWithApple: {
                    viewModel.handle(.signInWithApple)
                }
            )
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
        switch viewModel.state.activeReader {
        case .some(let source):
            FolioSourceReaderView(source: source) {
                viewModel.handle(.closeReader)
            }
        case .none:
            switch viewModel.state.selectedTab {
            case .sources:
                if viewModel.state.sourcesMode == .spaces {
                    FolioSpacesView(
                        spaces: viewModel.state.spaces,
                        onSelectSources: { viewModel.handle(.showLibrary) },
                        onSelectAsk: { viewModel.handle(.selectTab(.ask)) },
                        onSearch: {},
                        onAdd: {}
                    )
                } else {
                    FolioSourcesView(
                        filters: viewModel.state.sourceFilters,
                        selectedFilter: viewModel.state.selectedFilter,
                        sources: viewModel.visibleSources,
                        onSelectFilter: { viewModel.handle(.selectFilter($0)) },
                        onSelectSource: { viewModel.handle(.openReader($0)) },
                        onSearch: {},
                        onMenu: {}
                    )
                }
            case .ask:
                FolioAskView()
            case .notes:
                FolioPlaceholderView(
                    title: "Notes",
                    subtitle: "Capture claims, quotes, and follow-up ideas in one private space.",
                    iconName: "note.text"
                )
            case .notebook:
                FolioPlaceholderView(
                    title: "Notebook",
                    subtitle: "Organize drafts, syntheses, and research threads here.",
                    iconName: "book"
                )
            }
        }
    }
}

#Preview {
    MainView(viewModel: MainViewModel(
        fetchUsersUseCase: PreviewFetchUsersUseCase(),
        localStorage: UserDefaultsStorage()
    ))
}

private struct PreviewFetchUsersUseCase: FetchUsersUseCaseProtocol {
    func execute() async throws -> [User] { [] }
}
