import XCTest
@testable import Folio

@MainActor
final class AskConversationListViewModelTests: XCTestCase {

    func testOnAppearLoadsFirstPageAndGuardsDuplicateCalls() async {
        let conversation = AskConversation(id: "c1", title: "First Conversation", createdAt: Date(), updatedAt: Date())
        let fetchUseCase = MockFetchAskConversationsUseCase(result: AskConversationListResult(
            conversations: [conversation],
            pagination: AskConversationPagination(page: 1, limit: 10, totalCount: 1, totalPages: 1)
        ))
        let viewModel = makeViewModel(fetchUseCase: fetchUseCase)

        viewModel.handle(.onAppear)
        await waitForTasks()

        XCTAssertEqual(viewModel.state.conversations.count, 1)
        XCTAssertEqual(viewModel.state.conversations.first?.id, "c1")
        XCTAssertEqual(fetchUseCase.callCount, 1)

        // Second onAppear should be ignored because didLoad is true
        viewModel.handle(.onAppear)
        await waitForTasks()

        XCTAssertEqual(fetchUseCase.callCount, 1)
    }

    func testRefreshReplacesConversations() async {
        let initialConv = AskConversation(id: "c1", title: "Old Conversation", createdAt: Date(), updatedAt: Date())
        let refreshedConv = AskConversation(id: "c2", title: "New Conversation", createdAt: Date(), updatedAt: Date())

        let fetchUseCase = MockFetchAskConversationsUseCase(resultsByPage: [
            1: AskConversationListResult(
                conversations: [initialConv],
                pagination: AskConversationPagination(page: 1, limit: 10, totalCount: 1, totalPages: 1)
            )
        ])
        let viewModel = makeViewModel(fetchUseCase: fetchUseCase)

        viewModel.handle(.onAppear)
        await waitForTasks()

        XCTAssertEqual(viewModel.state.conversations.map(\.id), ["c1"])

        // Update mock to return new list on next fetch
        fetchUseCase.resultsByPage[1] = AskConversationListResult(
            conversations: [refreshedConv],
            pagination: AskConversationPagination(page: 1, limit: 10, totalCount: 1, totalPages: 1)
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.state.conversations.map(\.id), ["c2"])
    }

    func testLoadMoreAppendsUniqueConversations() async {
        let c1 = AskConversation(id: "c1", title: "Conv 1", createdAt: Date(), updatedAt: Date())
        let c2 = AskConversation(id: "c2", title: "Conv 2", createdAt: Date(), updatedAt: Date())

        let page1Result = AskConversationListResult(
            conversations: [c1],
            pagination: AskConversationPagination(page: 1, limit: 1, totalCount: 2, totalPages: 2)
        )
        let page2Result = AskConversationListResult(
            conversations: [c2],
            pagination: AskConversationPagination(page: 2, limit: 1, totalCount: 2, totalPages: 2)
        )

        let fetchUseCase = MockFetchAskConversationsUseCase(resultsByPage: [1: page1Result, 2: page2Result])
        let viewModel = makeViewModel(fetchUseCase: fetchUseCase)

        viewModel.handle(.onAppear)
        await waitForTasks()
        XCTAssertEqual(viewModel.state.conversations.map(\.id), ["c1"])

        viewModel.handle(.loadMore)
        await waitForTasks()
        XCTAssertEqual(viewModel.state.conversations.map(\.id), ["c1", "c2"])
    }

    func testDeleteConversationRemovesFromState() async {
        let c1 = AskConversation(id: "c1", title: "Conv 1", createdAt: Date(), updatedAt: Date())
        let fetchUseCase = MockFetchAskConversationsUseCase(result: AskConversationListResult(
            conversations: [c1],
            pagination: nil
        ))
        let deleteUseCase = MockDeleteConversationUseCase()
        let viewModel = makeViewModel(fetchUseCase: fetchUseCase, deleteUseCase: deleteUseCase)

        viewModel.handle(.onAppear)
        await waitForTasks()
        XCTAssertEqual(viewModel.state.conversations.count, 1)

        viewModel.handle(.deleteConversation(c1))
        await waitForTasks()

        XCTAssertEqual(viewModel.state.conversations.count, 0)
        XCTAssertEqual(deleteUseCase.deletedConversationId, "c1")
    }

    func testRenameConversationUpdatesTitleInState() async {
        let c1 = AskConversation(id: "c1", title: "Old Title", createdAt: Date(), updatedAt: Date())
        let fetchUseCase = MockFetchAskConversationsUseCase(result: AskConversationListResult(
            conversations: [c1],
            pagination: nil
        ))
        let renameUseCase = MockRenameConversationUseCase()
        let viewModel = makeViewModel(fetchUseCase: fetchUseCase, renameUseCase: renameUseCase)

        viewModel.handle(.onAppear)
        await waitForTasks()

        viewModel.handle(.renameConversation(c1, title: "New Title"))
        await waitForTasks()

        XCTAssertEqual(viewModel.state.conversations.first?.title, "New Title")
        XCTAssertEqual(renameUseCase.renamedTitle, "New Title")
    }

    // MARK: - Helpers

    private func makeViewModel(
        fetchUseCase: any FetchAskConversationsUseCaseProtocol = MockFetchAskConversationsUseCase(),
        deleteUseCase: any DeleteConversationUseCaseProtocol = MockDeleteConversationUseCase(),
        renameUseCase: any RenameConversationUseCaseProtocol = MockRenameConversationUseCase()
    ) -> AskConversationListViewModel {
        AskConversationListViewModel(
            spaceId: "space-1",
            fetchAskConversationsUseCase: fetchUseCase,
            deleteConversationUseCase: deleteUseCase,
            renameConversationUseCase: renameUseCase
        )
    }

    private func waitForTasks() async {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))
    }
}

// MARK: - Mocks

private final class MockFetchAskConversationsUseCase: FetchAskConversationsUseCaseProtocol, @unchecked Sendable {
    var callCount = 0
    var resultsByPage: [Int: AskConversationListResult]

    init(result: AskConversationListResult? = nil, resultsByPage: [Int: AskConversationListResult] = [:]) {
        self.resultsByPage = resultsByPage
        if let result {
            self.resultsByPage[1] = result
        }
    }

    func execute(query: AskConversationListQuery) async throws -> AskConversationListResult {
        callCount += 1
        let page = query.page ?? 1
        return resultsByPage[page] ?? AskConversationListResult(conversations: [], pagination: nil)
    }
}

private final class MockDeleteConversationUseCase: DeleteConversationUseCaseProtocol, @unchecked Sendable {
    var deletedConversationId: String?
    func execute(spaceId: String, conversationId: String) async throws {
        deletedConversationId = conversationId
    }
}

private final class MockRenameConversationUseCase: RenameConversationUseCaseProtocol, @unchecked Sendable {
    var renamedTitle: String?
    func execute(spaceId: String, conversationId: String, title: String) async throws {
        renamedTitle = title
    }
}
