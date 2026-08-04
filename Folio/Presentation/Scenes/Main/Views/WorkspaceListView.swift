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
            switch sheet {
            case .create:
                CreateSpaceSheetView(
                    isMutating: viewModel.state.isMutating,
                    errorMessage: viewModel.state.mutationError,
                    onCancel: { viewModel.send(.dismissSheet) },
                    onSubmit: { name, objective in viewModel.send(.create(name: name, objective: objective)) }
                )
            case .edit(let workspace):
                WorkspaceEditorSheet(
                    title: String(localized: "Edit Space"),
                    submitTitle: String(localized: "Save"),
                    initialName: workspace.name,
                    initialObjective: workspace.objective,
                    isMutating: viewModel.state.isMutating,
                    errorMessage: viewModel.state.mutationError,
                    onCancel: { viewModel.send(.dismissSheet) },
                    onSubmit: { name, objective in viewModel.send(.update(id: workspace.id, name: name, objective: objective)) }
                )
            }
        }
        .alert(
            String(localized: "Delete space?"),
            isPresented: Binding(
                get: { viewModel.state.confirmationWorkspace != nil },
                set: { if !$0 { viewModel.send(.dismissConfirmation) } }
            ),
            presenting: viewModel.state.confirmationWorkspace
        ) { workspace in
            Button(String(localized: "Cancel"), role: .cancel) { viewModel.send(.dismissConfirmation) }
            Button(String(localized: "Delete"), role: .destructive) { viewModel.send(.deleteConfirmed(workspace)) }
        } message: { _ in
            Text(String(localized: "This action cannot be undone. All sources, notes, and conversations inside this space will be permanently removed."))
        }
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
                    .frame(width: 60, height: 60)
                    .background(Color.folioOlive)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
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
                                .foregroundStyle(.red)
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
        VStack(spacing: 12) {
            FolioTopBar(
                title: "Folio",
                subtitle: "My Spaces",
                trailing: [
                    AnyView(FolioAccountAvatarButton(initial: userInitial, size: 36, action: onOpenAccountSettings))
                ]
            )
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.folioInkSoft)
                TextField(String(localized: "Search spaces"), text: Binding(
                    get: { viewModel.state.searchQuery },
                    set: { viewModel.send(.searchQueryChanged($0)) }
                ))
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                if !viewModel.state.searchQuery.isEmpty {
                    Button { viewModel.send(.clearSearch) } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.folioInkSoft)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color.folioSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 18)
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
        .background(Color.folioOlive)
    }
}

private struct WorkspaceCard: View {
    let workspace: Workspace
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onSelect) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            Text(String(workspace.name.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.folioInk)
                                .frame(width: 40, height: 40)
                                .background(Color.folioGold.opacity(0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(workspace.name)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.folioInk)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(workspace.updatedAt.workspaceRelativeLabel)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.folioInkSoft)
                            }
                        }

                        if !workspace.objective.isEmpty {
                            Text(workspace.objective)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.folioInkMuted)
                                .lineLimit(3)
                        }

                        Divider()

                        Text(
                            String(
                                format: String(localized: "%lld sources · %lld notes"),
                                locale: .current,
                                workspace.sourceCount,
                                workspace.noteCount
                            )
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(Color.folioInkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(String(localized: "Double tap to open"))

                Menu {
                    Button(String(localized: "Edit"), action: onEdit)
                    Button(
                        String(localized: "Delete"),
                        role: .destructive,
                        action: onDelete
                    )
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.folioInkMuted)
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel(
                    String(localized: "More options for \(workspace.name)")
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.folioSurfaceStrong)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.folioLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
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

private struct WorkspaceEditorSheet: View {
    let title: String
    let submitTitle: String
    var initialName = ""
    var initialObjective = ""
    let isMutating: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSubmit: (String, String) -> Void
    @State private var name: String
    @State private var objective: String

    init(title: String, submitTitle: String, initialName: String = "", initialObjective: String = "", isMutating: Bool, errorMessage: String?, onCancel: @escaping () -> Void, onSubmit: @escaping (String, String) -> Void) {
        self.title = title; self.submitTitle = submitTitle; self.initialName = initialName; self.initialObjective = initialObjective; self.isMutating = isMutating; self.errorMessage = errorMessage; self.onCancel = onCancel; self.onSubmit = onSubmit
        _name = State(initialValue: initialName)
        _objective = State(initialValue: initialObjective)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Space details")) {
                    TextField(String(localized: "Name"), text: $name)
                    TextField(String(localized: "Research objective (optional)"), text: $objective, axis: .vertical)
                        .lineLimit(3...6)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Cancel"), action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitTitle) { onSubmit(name, objective) }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isMutating)
                }
            }
            .overlay { if isMutating { ProgressView() } }
        }
        .presentationDetents([.medium, .large])
    }
}

private extension Date {
    var workspaceRelativeLabel: String {
        let minutes = max(0, Int(Date().timeIntervalSince(self) / 60))
        if minutes < 1 { return String(localized: "Updated just now") }
        if minutes < 60 { return String(localized: "Updated \(minutes) mins ago") }
        let hours = minutes / 60
        if hours < 24 { return String(localized: "Updated \(hours) hours ago") }
        if hours < 48 { return String(localized: "Updated Yesterday") }
        if hours < 24 * 7 { return String(localized: "Updated \(DateFormatter.workspaceWeekday.string(from: self))") }
        return String(localized: "Updated \(DateFormatter.workspaceDate.string(from: self))")
    }
}

private extension DateFormatter {
    static let workspaceWeekday: DateFormatter = { let formatter = DateFormatter(); formatter.dateFormat = "EEEE"; return formatter }()
    static let workspaceDate: DateFormatter = { let formatter = DateFormatter(); formatter.dateFormat = "MMM dd, yyyy"; return formatter }()
}
