import Foundation
import Combine

@MainActor
final class WorkspaceListViewModel: ObservableObject {
    struct State: Equatable {
        var isLoading = false
        var isLoadingNextPage = false
        var paginationErrorMessage: String?
        var errorMessage: String?
        var allWorkspaces: [Workspace] = []
        var visibleWorkspaces: [Workspace] = []
        var searchQuery = ""
        var sortOption = WorkspaceSortOption.recentlyUpdated
        var presentedSheet: Sheet?
        var confirmationWorkspace: Workspace?
        var isMutating = false
        var mutationError: String?
        var toastMessage: ToastMessage?
        var deletedWorkspaceID: String?
        var createdWorkspaceID: String?
        var pagination: WorkspacePagination?
        var currentPage = 0
        var totalPages = 0
        var totalCount = 0

        enum Sheet: Identifiable, Equatable {
            case create
            case edit(Workspace)
            case sortOptions

            var id: String {
                switch self {
                case .create: return "create"
                case .edit(let workspace): return "edit-\(workspace.id)"
                case .sortOptions: return "sort-options"
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
        case refresh
        case loadMore
        case searchQueryChanged(String)
        case clearSearch
        case sortTapped
        case sortSelected(WorkspaceSortOption)
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
            if !state.searchQuery.isEmpty {
                return .noSearchResults(searchQuery: state.searchQuery)
            }
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
    private var requestGeneration = 0
    private var searchTask: Task<Void, Never>?

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
            Task { await loadFirstPage() }
        case .retry:
            Task { await loadFirstPage() }
        case .refresh:
            Task { await loadFirstPage() }
        case .loadMore:
            Task { await loadNextPage() }
        case .searchQueryChanged(let query):
            guard query != state.searchQuery else { return }
            state.searchQuery = query
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !Task.isCancelled { await loadFirstPage() }
            }
        case .clearSearch:
            state.searchQuery = ""
            searchTask?.cancel()
            Task { await loadFirstPage() }
        case .sortTapped:
            state.presentedSheet = .sortOptions
        case .sortSelected(let option):
            guard option != state.sortOption else {
                state.presentedSheet = nil
                return
            }
            searchTask?.cancel()
            state.sortOption = option
            state.presentedSheet = nil
            Task { await loadFirstPage() }
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
            state.createdWorkspaceID = nil
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

    func refresh() async {
        await loadFirstPage()
    }

    private func loadFirstPage() async {
        requestGeneration += 1
        let generation = requestGeneration
        state.isLoading = true
        state.isLoadingNextPage = false
        state.errorMessage = nil
        state.paginationErrorMessage = nil
        defer {
            if generation == requestGeneration {
                state.isLoading = false
            }
        }
        do {
            let searchTerm = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let query = WorkspaceListQuery(
                sort: state.sortOption,
                search: searchTerm.isEmpty ? nil : searchTerm,
                page: nil,
                limit: nil
            )
            let result = try await fetchWorkspaces.execute(query: query)
            guard generation == requestGeneration else { return }
            replace(with: result)
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            guard generation == requestGeneration else { return }
            state.errorMessage = error.localizedDescription
            state.toastMessage = .error(error.localizedDescription)
        }
    }

    private func loadNextPage() async {
        guard let pagination = state.pagination,
              !state.isLoading,
               !state.isLoadingNextPage,
               pagination.page < pagination.totalPages else { return }

        state.isLoadingNextPage = true
        state.paginationErrorMessage = nil
        let generation = requestGeneration
        defer {
            if generation == requestGeneration {
                state.isLoadingNextPage = false
            }
        }
        do {
            let searchTerm = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let query = WorkspaceListQuery(
                sort: state.sortOption,
                search: searchTerm.isEmpty ? nil : searchTerm,
                page: pagination.page + 1,
                limit: pagination.limit
            )
            let result = try await fetchWorkspaces.execute(query: query)
            guard generation == requestGeneration else { return }
            append(result)
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            guard generation == requestGeneration else { return }
            state.paginationErrorMessage = error.localizedDescription
            state.toastMessage = .error(error.localizedDescription)
        }
    }

    private func append(_ result: WorkspaceListResult) {
        var existingIDs = Set(state.allWorkspaces.map(\.id))
        let newWorkspaces = result.workspaces.filter { workspace in
            guard existingIDs.insert(workspace.id).inserted else { return false }
            return true
        }
        state.allWorkspaces.append(contentsOf: newWorkspaces)
        state.pagination = result.pagination
        state.currentPage = result.pagination?.page ?? 0
        state.totalPages = result.pagination?.totalPages ?? 0
        state.totalCount = result.pagination?.totalCount ?? state.allWorkspaces.count
        applyFilter()
    }

    private func replace(with result: WorkspaceListResult) {
        state.allWorkspaces = result.workspaces
        state.pagination = result.pagination
        state.currentPage = result.pagination?.page ?? 0
        state.totalPages = result.pagination?.totalPages ?? 0
        state.totalCount = result.pagination?.totalCount ?? state.allWorkspaces.count
        applyFilter()
    }

    private func create(name: String, objective: String) async {
        guard !state.isMutating else { return }
        invalidateInFlightListLoads()
        state.createdWorkspaceID = nil
        await runMutation(fallbackMessage: "Failed to create space. Please try again.") {
            let workspace = try await self.createWorkspace.execute(name: name, objective: objective)
            self.state.allWorkspaces.insert(workspace, at: 0)
            self.applyFilter()
            self.state.presentedSheet = nil
            self.state.createdWorkspaceID = workspace.id
        }
    }

    private func update(id: String, name: String, objective: String) async {
        guard !state.isMutating else { return }
        invalidateInFlightListLoads()
        await runMutation(fallbackMessage: "Failed to update space. Please try again.") {
            let workspace = try await self.updateWorkspace.execute(id: id, name: name, objective: objective)
            if let index = self.state.allWorkspaces.firstIndex(where: { $0.id == id }) {
                self.state.allWorkspaces[index] = workspace
                self.applyFilter()
            }
            self.state.presentedSheet = nil
            self.state.toastMessage = .success(String(localized: "Space updated"))
        }
    }

    private func delete(workspace: Workspace) async {
        guard !state.isMutating else { return }
        invalidateInFlightListLoads()
        var didDelete = false
        await runMutation(fallbackMessage: "Failed to delete space. Please try again.") {
            try await self.deleteWorkspace.execute(id: workspace.id)
            self.state.allWorkspaces.removeAll { $0.id == workspace.id }
            self.applyFilter()
            self.state.deletedWorkspaceID = workspace.id
            self.state.toastMessage = .success(String(localized: "Space deleted"))
            didDelete = true
        }
        if didDelete { await loadFirstPage() }
    }

    private func invalidateInFlightListLoads() {
        requestGeneration += 1
        state.isLoading = false
        state.isLoadingNextPage = false
    }

    private func runMutation(fallbackMessage: String.LocalizationValue, _ operation: @escaping () async throws -> Void) async {
        state.isMutating = true
        state.mutationError = nil
        do {
            try await operation()
        } catch is CancellationError {
        } catch let error as WorkspaceRepositoryError {
            state.mutationError = error.errorDescription
            state.toastMessage = .error(error.errorDescription ?? error.localizedDescription)
        } catch {
            let message = String(localized: fallbackMessage)
            state.mutationError = message
            state.toastMessage = .error(message)
        }
        state.isMutating = false
    }

    private func applyFilter() {
        state.allWorkspaces = sortedWorkspaces(state.allWorkspaces)
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state.visibleWorkspaces = state.allWorkspaces
            return
        }
        state.visibleWorkspaces = state.allWorkspaces.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.objective.localizedCaseInsensitiveContains(query)
        }
    }

    private func sortedWorkspaces(_ workspaces: [Workspace]) -> [Workspace] {
        switch state.sortOption {
        case .alphabeticalAZ:
            return workspaces.sorted { workspaceComesBefore($0, $1, ascending: true) }
        case .alphabeticalZA:
            return workspaces.sorted { workspaceComesBefore($0, $1, ascending: false) }
        case .recentlyUpdated:
            return workspaces.sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.id < rhs.id
            }
        case .recentlyCreated:
            return workspaces
        }
    }

    private func workspaceComesBefore(_ lhs: Workspace, _ rhs: Workspace, ascending: Bool) -> Bool {
        let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        guard nameComparison != .orderedSame else { return lhs.id < rhs.id }
        return ascending
            ? nameComparison == .orderedAscending
            : nameComparison == .orderedDescending
    }
}
