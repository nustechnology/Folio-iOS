import XCTest
@testable import Folio

@MainActor
final class WorkspaceListPaginationTests: XCTestCase {
    func testInitialLoadAndLoadMoreAppendOnlyUniqueWorkspaces() async {
        let first = WorkspaceListResult(
            workspaces: [workspace(id: "one"), workspace(id: "two")],
            pagination: WorkspacePagination(page: 1, limit: 2, totalCount: 3, totalPages: 2)
        )
        let second = WorkspaceListResult(
            workspaces: [workspace(id: "two"), workspace(id: "three"), workspace(id: "three")],
            pagination: WorkspacePagination(page: 2, limit: 2, totalCount: 3, totalPages: 2)
        )
        let fetch = RecordingFetchWorkspacesUseCase(pages: [1: first, 2: second])
        let viewModel = makeViewModel(fetch: fetch)

        viewModel.send(.appeared)
        await waitForTasks()
        viewModel.send(.loadMore)
        await waitForTasks()

        XCTAssertEqual(viewModel.state.allWorkspaces.map(\.id), ["one", "two", "three"])
        XCTAssertEqual(fetch.requests.compactMap(\.page), [2])
    }

    func testConcurrentLoadMoreTriggersProduceOneRequest() async {
        let first = WorkspaceListResult(workspaces: [workspace(id: "one")], pagination: WorkspacePagination(page: 1, limit: 1, totalCount: 2, totalPages: 2))
        let second = WorkspaceListResult(workspaces: [workspace(id: "two")], pagination: WorkspacePagination(page: 2, limit: 1, totalCount: 2, totalPages: 2))
        let fetch = RecordingFetchWorkspacesUseCase(pages: [1: first, 2: second])
        let viewModel = makeViewModel(fetch: fetch)

        viewModel.send(.appeared)
        await waitForTasks()
        viewModel.send(.loadMore)
        viewModel.send(.loadMore)
        await waitForTasks()

        XCTAssertEqual(fetch.requests.compactMap(\.page), [2])
    }

    func testLoadMoreDoesNotRequestAfterLastPage() async {
        let page = WorkspaceListResult(
            workspaces: [workspace(id: "one")],
            pagination: WorkspacePagination(page: 1, limit: 10, totalCount: 1, totalPages: 1)
        )
        let fetch = RecordingFetchWorkspacesUseCase(pages: [1: page])
        let viewModel = makeViewModel(fetch: fetch)

        viewModel.send(.appeared)
        await waitForTasks()
        viewModel.send(.loadMore)
        await waitForTasks()

        XCTAssertEqual(fetch.requests.count, 1)
    }

    func testLoadMoreContinuesWhenCreateMakesLocalCountReachServerTotal() async {
        let first = WorkspaceListResult(
            workspaces: (1...10).map { workspace(id: "server-\($0)") },
            pagination: WorkspacePagination(page: 1, limit: 10, totalCount: 11, totalPages: 2)
        )
        let second = WorkspaceListResult(
            workspaces: [workspace(id: "server-11")],
            pagination: WorkspacePagination(page: 2, limit: 10, totalCount: 11, totalPages: 2)
        )
        let fetch = RecordingFetchWorkspacesUseCase(pages: [1: first, 2: second])
        let viewModel = makeViewModel(fetch: fetch, create: ReturningCreateWorkspaceUseCase(workspace: workspace(id: "local")))

        viewModel.send(.appeared)
        await waitForTasks()
        viewModel.send(.create(name: "local", objective: ""))
        await waitForTasks()
        viewModel.send(.loadMore)
        await waitForTasks()

        XCTAssertEqual(fetch.requests.compactMap(\.page), [2])
        XCTAssertTrue(viewModel.state.allWorkspaces.contains(where: { $0.id == "server-11" }))
    }

    func testCreateKeepsNonMatchingWorkspaceOutOfActiveSearchResults() async {
        let matching = workspace(id: "matching", name: "Research plan")
        let fetch = RecordingFetchWorkspacesUseCase(results: [WorkspaceListResult(workspaces: [matching], pagination: nil)])
        let viewModel = makeViewModel(fetch: fetch, create: ReturningCreateWorkspaceUseCase(workspace: workspace(id: "other", name: "Shopping list")))

        viewModel.send(.appeared)
        await waitForTasks()
        viewModel.send(.searchQueryChanged("research"))
        try? await Task.sleep(nanoseconds: 350_000_000)
        await waitForTasks()
        viewModel.send(.create(name: "Shopping list", objective: ""))
        await waitForTasks()

        XCTAssertEqual(viewModel.state.visibleWorkspaces.map(\.id), ["matching"])
    }

    func testUpdateReplacesOnlyMatchingWorkspaceAndClosesSheet() async {
        let original = workspace(id: "one", name: "Original")
        let other = workspace(id: "two", name: "Other")
        let updated = Workspace(id: "one", name: "Updated", objective: "New objective", sourceCount: 3, noteCount: 2, updatedAt: .now)
        let fetch = RecordingFetchWorkspacesUseCase(results: [WorkspaceListResult(workspaces: [original, other], pagination: nil)])
        let viewModel = makeViewModel(fetch: fetch, update: ReturningUpdateWorkspaceUseCase(workspace: updated))

        viewModel.send(.appeared)
        await waitForTasks()
        viewModel.send(.editTapped(original))
        viewModel.send(.update(id: original.id, name: "Updated", objective: "New objective"))
        await waitForTasks()

        XCTAssertEqual(viewModel.state.allWorkspaces.map(\.name), ["Updated", "Other"])
        XCTAssertNil(viewModel.state.presentedSheet)
        XCTAssertEqual(viewModel.state.toastMessage, .success(String(localized: "Space updated")))
    }

    func testUpdateFailurePreservesEditSheetAndDraftMutationState() async {
        let original = workspace(id: "one", name: "Original")
        let fetch = RecordingFetchWorkspacesUseCase(results: [WorkspaceListResult(workspaces: [original], pagination: nil)])
        let viewModel = makeViewModel(fetch: fetch, update: FailingUpdateWorkspaceUseCase())

        viewModel.send(.appeared)
        await waitForTasks()
        viewModel.send(.editTapped(original))
        viewModel.send(.update(id: original.id, name: "Draft name", objective: "Draft objective"))
        await waitForTasks()

        XCTAssertEqual(viewModel.state.presentedSheet, .edit(original))
        XCTAssertFalse(viewModel.state.isMutating)
        XCTAssertNotNil(viewModel.state.mutationError)
        XCTAssertNotNil(viewModel.state.toastMessage)
    }

    func testRefreshResetsPaginationAndLoadsPageOne() async {
        let pageOne = WorkspaceListResult(workspaces: [workspace(id: "one")], pagination: WorkspacePagination(page: 1, limit: 1, totalCount: 2, totalPages: 2))
        let pageTwo = WorkspaceListResult(workspaces: [workspace(id: "two")], pagination: WorkspacePagination(page: 2, limit: 1, totalCount: 2, totalPages: 2))
        let refreshed = WorkspaceListResult(workspaces: [workspace(id: "fresh")], pagination: WorkspacePagination(page: 1, limit: 1, totalCount: 1, totalPages: 1))
        let fetch = RecordingFetchWorkspacesUseCase(pages: [1: pageOne, 2: pageTwo], refreshPage: refreshed)
        let viewModel = makeViewModel(fetch: fetch)

        viewModel.send(.appeared)
        await waitForTasks()
        viewModel.send(.loadMore)
        await waitForTasks()
        viewModel.send(.refresh)
        await waitForTasks()

        XCTAssertEqual(viewModel.state.allWorkspaces.map(\.id), ["fresh"])
        XCTAssertEqual(fetch.requests.compactMap(\.page), [2])
    }

    private func makeViewModel<Fetch: FetchWorkspacesUseCaseProtocol>(
        fetch: Fetch,
        create: any CreateWorkspaceUseCaseProtocol = EmptyCreateWorkspaceUseCase(),
        update: any UpdateWorkspaceUseCaseProtocol = EmptyUpdateWorkspaceUseCase()
    ) -> WorkspaceListViewModel {
        WorkspaceListViewModel(
            fetchWorkspaces: fetch,
            createWorkspace: create,
            updateWorkspace: update,
            deleteWorkspace: EmptyDeleteWorkspaceUseCase()
        )
    }

    func testDelayedListResponseDoesNotOverwriteEditedWorkspaceAfterMutation() async {
        let original = workspace(id: "one", name: "Original")
        let other = workspace(id: "two", name: "Other")
        let preEditPage = WorkspaceListResult(
            workspaces: [original, other],
            pagination: WorkspacePagination(page: 1, limit: 10, totalCount: 2, totalPages: 1)
        )
        let updated = Workspace(id: "one", name: "Updated", objective: "Objective", sourceCount: 0, noteCount: 0, updatedAt: .now)
        let fetch = ControlledFetchWorkspacesUseCase(initialResult: preEditPage)
        let viewModel = makeViewModel(fetch: fetch, update: ReturningUpdateWorkspaceUseCase(workspace: updated))

        viewModel.send(.appeared)
        await waitForTasks()
        XCTAssertEqual(viewModel.state.allWorkspaces.map(\.id), ["one", "two"])

        viewModel.send(.refresh)
        await waitForTasks()
        viewModel.send(.editTapped(original))
        viewModel.send(.update(id: original.id, name: "Updated", objective: "Objective"))
        await waitForTasks()

        XCTAssertEqual(viewModel.state.allWorkspaces.first(where: { $0.id == "one" })?.name, "Updated")
        XCTAssertFalse(viewModel.state.isLoading)

        fetch.releaseNext(preEditPage)
        await waitForTasks()

        XCTAssertEqual(viewModel.state.allWorkspaces.first(where: { $0.id == "one" })?.name, "Updated")
    }

    func testNonPaginatedResultDoesNotTriggerLoadMore() async {
        let fetch = RecordingFetchWorkspacesUseCase(results: [WorkspaceListResult(workspaces: [workspace(id: "one")], pagination: nil)])
        let viewModel = makeViewModel(fetch: fetch)

        viewModel.send(.appeared)
        await waitForTasks()
        viewModel.send(.loadMore)
        await waitForTasks()

        XCTAssertEqual(fetch.requests.count, 1)
        XCTAssertNil(viewModel.state.pagination)
    }

    private func workspace(id: String, name: String? = nil) -> Workspace {
        Workspace(id: id, name: name ?? id, objective: "", sourceCount: 0, noteCount: 0, updatedAt: .now)
    }

    private func waitForTasks() async {
        await Task.yield()
        await Task.yield()
    }
}

@MainActor
private final class RecordingFetchWorkspacesUseCase: FetchWorkspacesUseCaseProtocol {
    struct Request {
        let page: Int?
        let limit: Int?
    }

    private let pages: [Int: WorkspaceListResult]
    private let refreshPage: WorkspaceListResult?
    private(set) var requests: [Request] = []

    init(pages: [Int: WorkspaceListResult], refreshPage: WorkspaceListResult? = nil) {
        self.pages = pages
        self.refreshPage = refreshPage
    }

    convenience init(results: [WorkspaceListResult]) {
        self.init(pages: Dictionary(uniqueKeysWithValues: results.enumerated().map { ($0.offset + 1, $0.element) }))
    }

    func execute(query: WorkspaceListQuery) async throws -> WorkspaceListResult {
        requests.append(Request(page: query.page, limit: query.limit))
        if requests.count > pages.count, let refreshPage {
            return refreshPage
        }
        return pages[query.page ?? 1]!
    }
}

@MainActor
private final class ControlledFetchWorkspacesUseCase: FetchWorkspacesUseCaseProtocol {
    private let initialResult: WorkspaceListResult
    private var callCount = 0
    private var continuations: [CheckedContinuation<WorkspaceListResult, Error>] = []

    init(initialResult: WorkspaceListResult) {
        self.initialResult = initialResult
    }

    func execute(query: WorkspaceListQuery) async throws -> WorkspaceListResult {
        callCount += 1
        if callCount == 1 {
            return initialResult
        }
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func releaseNext(_ result: WorkspaceListResult) {
        let continuation = continuations.removeFirst()
        continuation.resume(returning: result)
    }
}

private struct EmptyCreateWorkspaceUseCase: CreateWorkspaceUseCaseProtocol {
    func execute(name: String, objective: String) async throws -> Workspace { fatalError("Not used") }
}

private struct ReturningCreateWorkspaceUseCase: CreateWorkspaceUseCaseProtocol {
    let workspace: Workspace

    func execute(name: String, objective: String) async throws -> Workspace {
        workspace
    }
}

private struct ReturningUpdateWorkspaceUseCase: UpdateWorkspaceUseCaseProtocol {
    let workspace: Workspace

    func execute(id: String, name: String, objective: String) async throws -> Workspace {
        workspace
    }
}

private struct FailingUpdateWorkspaceUseCase: UpdateWorkspaceUseCaseProtocol {
    func execute(id: String, name: String, objective: String) async throws -> Workspace {
        throw WorkspaceRepositoryError.failed("Update failed")
    }
}

private struct EmptyUpdateWorkspaceUseCase: UpdateWorkspaceUseCaseProtocol {
    func execute(id: String, name: String, objective: String) async throws -> Workspace { fatalError("Not used") }
}

private struct EmptyDeleteWorkspaceUseCase: DeleteWorkspaceUseCaseProtocol {
    func execute(id: String) async throws {}
}
