import Foundation
import Combine

@MainActor
final class WorkspaceListViewModel: ObservableObject {
    struct State: Equatable {
        var isLoading = false
        var errorMessage: String?
        var allWorkspaces: [Workspace] = []
        var visibleWorkspaces: [Workspace] = []
        var searchQuery = ""
        var isSearchVisible = false
        var presentedSheet: Sheet?
        var confirmationWorkspace: Workspace?
        var isMutating = false
        var mutationError: String?
        var toastMessage: String?
        var deletedWorkspaceID: String?

        enum Sheet: Identifiable, Equatable {
            case create
            case edit(Workspace)

            var id: String {
                switch self {
                case .create: return "create"
                case .edit(let workspace): return "edit-\(workspace.id)"
                }
            }
        }
    }

    enum WorkspaceContentState: Equatable {
        case loading
        case error(String)
        case empty
        case noSearchResults(searchQuery: String)
        case loaded([Workspace])
    }

    enum Intent {
        case appeared
        case retry
        case toggleSearch
        case searchQueryChanged(String)
        case clearSearch
        case createTapped
        case editTapped(Workspace)
        case deleteTapped(Workspace)
        case dismissSheet
        case dismissConfirmation
        case create(name: String, objective: String)
        case update(id: String, name: String, objective: String)
        case deleteConfirmed(Workspace)
        case dismissToast
    }

    @Published private(set) var state = State()

    var contentState: WorkspaceContentState {
        if state.isLoading && state.allWorkspaces.isEmpty {
            return .loading
        }
        if let error = state.errorMessage, state.allWorkspaces.isEmpty {
            return .error(error)
        }
        if state.allWorkspaces.isEmpty {
            return .empty
        }
        if state.visibleWorkspaces.isEmpty {
            return .noSearchResults(searchQuery: state.searchQuery)
        }
        return .loaded(state.visibleWorkspaces)
    }

    private let fetchWorkspaces: FetchWorkspacesUseCaseProtocol
    private let createWorkspace: CreateWorkspaceUseCaseProtocol
    private let updateWorkspace: UpdateWorkspaceUseCaseProtocol
    private let deleteWorkspace: DeleteWorkspaceUseCaseProtocol
    private var hasAppeared = false

    init(
        repository: WorkspaceRepositoryProtocol
    ) {
        self.fetchWorkspaces = FetchWorkspacesUseCase(repository: repository)
        self.createWorkspace = CreateWorkspaceUseCase(repository: repository)
        self.updateWorkspace = UpdateWorkspaceUseCase(repository: repository)
        self.deleteWorkspace = DeleteWorkspaceUseCase(repository: repository)
    }

    init(
        fetchWorkspaces: FetchWorkspacesUseCaseProtocol,
        createWorkspace: CreateWorkspaceUseCaseProtocol,
        updateWorkspace: UpdateWorkspaceUseCaseProtocol,
        deleteWorkspace: DeleteWorkspaceUseCaseProtocol
    ) {
        self.fetchWorkspaces = fetchWorkspaces
        self.createWorkspace = createWorkspace
        self.updateWorkspace = updateWorkspace
        self.deleteWorkspace = deleteWorkspace
    }

    func send(_ intent: Intent) {
        switch intent {
        case .appeared:
            guard !hasAppeared else { return }
            hasAppeared = true
            Task { await load() }
        case .retry:
            Task { await load() }
        case .toggleSearch:
            state.isSearchVisible.toggle()
            if !state.isSearchVisible { state.searchQuery = "" }
            applyFilter()
        case .searchQueryChanged(let query):
            state.searchQuery = query
            applyFilter()
        case .clearSearch:
            state.searchQuery = ""
            applyFilter()
        case .createTapped:
            state.mutationError = nil
            state.presentedSheet = .create
        case .editTapped(let workspace):
            state.mutationError = nil
            state.presentedSheet = .edit(workspace)
        case .deleteTapped(let workspace):
            state.confirmationWorkspace = workspace
        case .dismissSheet:
            state.presentedSheet = nil
            state.mutationError = nil
        case .dismissConfirmation:
            state.confirmationWorkspace = nil
        case .create(let name, let objective):
            Task { await create(name: name, objective: objective) }
        case .update(let id, let name, let objective):
            Task { await update(id: id, name: name, objective: objective) }
        case .deleteConfirmed(let workspace):
            state.confirmationWorkspace = nil
            Task { await delete(workspace: workspace) }
        case .dismissToast:
            state.toastMessage = nil
        }
    }

    private func load() async {
        state.isLoading = true
        state.errorMessage = nil
        defer { state.isLoading = false }
        do {
            state.allWorkspaces = try await fetchWorkspaces.execute()
            applyFilter()
        } catch is CancellationError {
            return
        } catch {
            state.errorMessage = error.localizedDescription
            state.toastMessage = error.localizedDescription
        }
    }

    private func create(name: String, objective: String) async {
        guard !state.isMutating else { return }
        await runMutation {
            let workspace = try await self.createWorkspace.execute(name: name, objective: objective)
            self.state.allWorkspaces.insert(workspace, at: 0)
            self.applyFilter()
            self.state.presentedSheet = nil
            self.state.toastMessage = String(localized: "Space created")
        }
    }

    private func update(id: String, name: String, objective: String) async {
        guard !state.isMutating else { return }
        await runMutation {
            let workspace = try await self.updateWorkspace.execute(id: id, name: name, objective: objective)
            if let index = self.state.allWorkspaces.firstIndex(where: { $0.id == id }) {
                self.state.allWorkspaces[index] = workspace
                self.applyFilter()
            }
            self.state.presentedSheet = nil
            self.state.toastMessage = String(localized: "Space updated")
        }
    }

    private func delete(workspace: Workspace) async {
        guard !state.isMutating else { return }
        await runMutation {
            try await self.deleteWorkspace.execute(id: workspace.id)
            self.state.allWorkspaces.removeAll { $0.id == workspace.id }
            self.applyFilter()
            self.state.deletedWorkspaceID = workspace.id
            self.state.toastMessage = String(localized: "Space deleted")
        }
    }

    private func runMutation(_ operation: @escaping () async throws -> Void) async {
        state.isMutating = true
        state.mutationError = nil
        do {
            try await operation()
        } catch is CancellationError {
            // Preserve the draft and let the caller retry.
        } catch {
            state.mutationError = error.localizedDescription
            state.toastMessage = error.localizedDescription
        }
        state.isMutating = false
    }

    private func applyFilter() {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state.visibleWorkspaces = state.allWorkspaces
            return
        }
        state.visibleWorkspaces = state.allWorkspaces.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.objective.localizedCaseInsensitiveContains(query)
        }
    }
}
