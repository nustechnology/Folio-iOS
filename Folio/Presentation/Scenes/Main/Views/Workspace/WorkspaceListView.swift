import SwiftUI

struct WorkspaceListView: View {
    @StateObject private var viewModel: WorkspaceListViewModel
    let onSelectWorkspace: (Workspace) -> Void
    let onWorkspaceCreated: (Workspace) -> Void
    let onWorkspaceDeleted: (String) -> Void
    let onToast: (String) -> Void
    let onOpenAccountSettings: () -> Void
    let userInitial: String
    
    init(
        viewModel: WorkspaceListViewModel,
        onSelectWorkspace: @escaping (Workspace) -> Void,
        onWorkspaceCreated: @escaping (Workspace) -> Void = { _ in },
        onWorkspaceDeleted: @escaping (String) -> Void = { _ in },
        onToast: @escaping (String) -> Void = { _ in },
        onOpenAccountSettings: @escaping () -> Void,
        userInitial: String
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelectWorkspace = onSelectWorkspace
        self.onWorkspaceCreated = onWorkspaceCreated
        self.onWorkspaceDeleted = onWorkspaceDeleted
        self.onToast = onToast
        self.onOpenAccountSettings = onOpenAccountSettings
        self.userInitial = userInitial
    }
    
    var body: some View {
        ZStack {
            Color.folioCanvas.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                content
            }
        }
        .task { viewModel.send(.appeared) }
        .onChange(of: viewModel.state.deletedWorkspaceID) { _, workspaceID in
            guard let workspaceID else { return }
            onWorkspaceDeleted(workspaceID)
        }
        .onChange(of: viewModel.state.createdWorkspaceID) { _, workspaceID in
            guard let workspaceID else { return }
            if let workspace = viewModel.state.allWorkspaces.first(where: { $0.id == workspaceID }) {
                onToast(String(localized: "Space created"))
                onWorkspaceCreated(workspace)
            }
        }
        .sheet(item: Binding(
            get: { viewModel.state.presentedSheet },
            set: { _ in viewModel.send(.dismissSheet) }
        )) { sheet in
            sheetContent(sheet)
        }
        .deleteConfirmationOverlay(
            isPresented: viewModel.state.confirmationWorkspace != nil,
            title: String(localized: "Delete space?"),
            message: String(
                localized: "This action cannot be undone. All sources, notes, and conversations inside this space will be permanently removed."
            ),
            onCancel: { viewModel.send(.dismissConfirmation) },
            onDelete: {
                guard let workspace = viewModel.state.confirmationWorkspace else { return }
                viewModel.send(.deleteConfirmed(workspace))
            }
        )
        .folioToast(message: Binding(
            get: { viewModel.state.toastMessage },
            set: { _ in viewModel.send(.dismissToast) }
        )).overlay(alignment: .bottomTrailing) {
            Button {
                viewModel.send(.createTapped)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Color.folioOlive)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: WorkspaceListViewModel.State.Sheet) -> some View {
        switch sheet {
        case .edit(let workspace):
            WorkspaceEditorSheet(
                title: String(localized: "Edit Space"),
                subtitle: String(localized: "Update the details for this research space."),
                submitTitle: String(localized: "Save"),
                initialName: workspace.name,
                initialObjective: workspace.objective,
                isMutating: viewModel.state.isMutating,
                errorMessage: viewModel.state.mutationError,
                onCancel: { viewModel.send(.dismissSheet) },
                onSubmit: { name, objective in
                    viewModel.send(.update(id: workspace.id, name: name, objective: objective))
                }
            )
        case .create:
            CreateSpaceSheetView(
                isMutating: viewModel.state.isMutating,
                errorMessage: viewModel.state.mutationError,
                onCancel: { viewModel.send(.dismissSheet) },
                onSubmit: { name, objective in
                    viewModel.send(.create(name: name, objective: objective))
                }
            )
        case .sortOptions:
            SortOptionsSheet<WorkspaceSortOption>(
                title: String(localized: "Sort spaces"),
                options: WorkspaceSortOption.allCases,
                selectedValue: viewModel.state.sortOption,
                onSelect: { viewModel.send(.sortSelected($0)) }
            )
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.contentState {
        case .loading:
            ProgressView().tint(Color.folioOlive).frame(maxHeight: .infinity)
        case .error(let message):
            WorkspaceMessageState(title: message, actionTitle: String(localized: "Retry"), action: { viewModel.send(.retry) })
        case .empty:
            WorkspaceMessageState(title: String(localized: "No research spaces yet"), subtitle: String(localized: "Create your first space to start collecting sources and making notes."), actionTitle: String(localized: "Create Space"), action: { viewModel.send(.createTapped) })
        case .noSearchResults(let searchQuery):
            WorkspaceMessageState(title: String(localized: "No spaces found matching \"\(searchQuery)\""), systemImage: "magnifyingglass", actionTitle: String(localized: "Clear search"), action: { viewModel.send(.clearSearch) })
        case .loaded(let workspaces):
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(workspaces.enumerated()), id: \.element.id) { index, workspace in
                        WorkspaceCard(workspace: workspace, onSelect: {
                            onSelectWorkspace(workspace)
                        }, onEdit: {
                            viewModel.send(.editTapped(workspace))
                        }, onDelete: {
                            viewModel.send(.deleteTapped(workspace))
                        })
                        .onAppear {
                            if index == workspaces.index(before: workspaces.endIndex) {
                                viewModel.send(.loadMore)
                            }
                        }
                    }
                    if viewModel.state.isLoadingNextPage {
                        ProgressView()
                            .tint(Color.folioOlive)
                            .padding(.vertical, 12)
                    } else if let error = viewModel.state.paginationErrorMessage {
                        VStack(spacing: 6) {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(Color.folioDanger)
                                .multilineTextAlignment(.center)
                            Button(String(localized: "Retry")) {
                                viewModel.send(.loadMore)
                            }
                            .tint(Color.folioOlive)
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(18)
            }
            .refreshable { await viewModel.refresh() }
        }
    }
    
    private var header: some View {
        FolioSearchHeader(
            title: String(localized: "Folio"),
            subtitle: String(localized: "My Spaces"),
            searchPlaceholder: String(localized: "Search spaces"),
            userInitial: userInitial,
            searchText: Binding(
                get: { viewModel.state.searchQuery },
                set: { viewModel.send(.searchQueryChanged($0)) }
            ),
            onOpenAccountSettings: onOpenAccountSettings,
            onClearSearch: { viewModel.send(.clearSearch) },
            onSortTapped: { viewModel.send(.sortTapped) },
            isSortActive: viewModel.state.sortOption != .recentlyUpdated
        )
    }
}

private struct WorkspaceMessageState: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 32))
                    .foregroundStyle(Color.folioInkSoft)
            }
            Text(title).font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.folioInk).multilineTextAlignment(.center)
            if let subtitle { Text(subtitle).font(.system(size: 14)).foregroundStyle(Color.folioInkMuted).multilineTextAlignment(.center) }
            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.folioOlive)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
