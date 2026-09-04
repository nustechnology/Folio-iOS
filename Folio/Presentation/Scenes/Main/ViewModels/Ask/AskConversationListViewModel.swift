import Combine
import Foundation

@MainActor
final class AskConversationListViewModel: ViewModelProtocol {
    struct State: Equatable {
        var conversations: [AskConversation] = []
        var isLoading = false
        var isLoadingNextPage = false
        var errorMessage: String?
        var paginationErrorMessage: String?
        var pagination: AskConversationPagination?
        var searchQuery = ""
    }

    enum Action {
        case onAppear
        case refresh
        case retry
        case loadMore
        case searchQueryChanged(String)
        case deleteConversation(AskConversation)
        case renameConversation(AskConversation, title: String)
    }

    private static let pageSize = 10
    private static let searchDebounceDuration: TimeInterval = 0.4
    static let titleMaxLength = 255

    @Published private(set) var state = State()
    @Published var toastMessage: ToastMessage? = nil

    let spaceId: String
    private let fetchAskConversationsUseCase: any FetchAskConversationsUseCaseProtocol
    private let deleteConversationUseCase: any DeleteConversationUseCaseProtocol
    private let renameConversationUseCase: any RenameConversationUseCaseProtocol
    private var didLoad = false
    private var latestLoadRequestID = 0
    private var searchDebounceTask: Task<Void, Never>?

    init(
        spaceId: String,
        fetchAskConversationsUseCase: any FetchAskConversationsUseCaseProtocol,
        deleteConversationUseCase: any DeleteConversationUseCaseProtocol,
        renameConversationUseCase: any RenameConversationUseCaseProtocol
    ) {
        self.spaceId = spaceId
        self.fetchAskConversationsUseCase = fetchAskConversationsUseCase
        self.deleteConversationUseCase = deleteConversationUseCase
        self.renameConversationUseCase = renameConversationUseCase
    }

    var filteredConversations: [AskConversation] {
        state.conversations
    }

    func handle(_ action: Action) {
        switch action {
        case .onAppear:
            guard !didLoad else { return }
            didLoad = true
            Task { await loadPage(replace: true) }
        case .refresh:
            Task { await loadPage(replace: true) }
        case .retry:
            Task { await loadPage(replace: true) }
        case .loadMore:
            loadMore()
        case .searchQueryChanged(let query):
            state.searchQuery = query
            latestLoadRequestID += 1
            debounceSearch()
        case .deleteConversation(let conversation):
            Task { await performDelete(conversation) }
        case .renameConversation(let conversation, let title):
            Task { await performRename(conversation, title: title) }
        }
    }

    func refresh() async {
        let refreshTask = Task { await loadPage(replace: true) }
        await refreshTask.value
    }

    private func debounceSearch() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(Self.searchDebounceDuration * 1000)))
            guard !Task.isCancelled else { return }
            await self?.loadPage(replace: true)
        }
    }

    private func loadMore() {
        guard let pagination = state.pagination,
            pagination.page < pagination.totalPages,
            !state.isLoading,
            !state.isLoadingNextPage
        else { return }

        state.paginationErrorMessage = nil
        state.isLoadingNextPage = true
        Task { await loadPage(replace: false) }
    }

    private func loadPage(replace: Bool) async {
        latestLoadRequestID += 1
        let requestID = latestLoadRequestID

        if replace {
            state.isLoading = true
            state.errorMessage = nil
            state.paginationErrorMessage = nil
        } else {
            state.isLoadingNextPage = true
        }

        defer {
            if requestID == latestLoadRequestID {
                state.isLoading = false
                state.isLoadingNextPage = false
            }
        }

        do {
            let page = replace ? 1 : (state.pagination?.page ?? 0) + 1
            let search = state.searchQuery.isEmpty ? nil : state.searchQuery
            let query = AskConversationListQuery(spaceId: spaceId, page: page, limit: Self.pageSize, search: search)
            let result = try await fetchAskConversationsUseCase.execute(query: query)

            guard requestID == latestLoadRequestID else { return }
            state.conversations = replace ? result.conversations : mergedConversations(with: result.conversations)
            state.pagination = result.pagination
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            guard requestID == latestLoadRequestID else { return }

            if replace {
                state.errorMessage = String(localized: "Failed to load conversations. Please try again.")
            } else {
                state.paginationErrorMessage = String(localized: "Failed to load conversations. Please try again.")
            }
            Logger.error("Failed to load ask conversations for space \(spaceId): \(error)")
        }
    }

    private func performDelete(_ conversation: AskConversation) async {
        do {
            try await deleteConversationUseCase.execute(spaceId: spaceId, conversationId: conversation.id)
            state.conversations.removeAll { $0.id == conversation.id }
            toastMessage = .success(String(localized: "Conversation deleted"))
        } catch {
            Logger.error("Failed to delete conversation: \(error)")
            toastMessage = .error(String(localized: "Failed to delete conversation. Please try again."))
        }
    }

    private func performRename(_ conversation: AskConversation, title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.titleMaxLength else { return }
        do {
            try await renameConversationUseCase.execute(spaceId: spaceId, conversationId: conversation.id, title: trimmed)
            if let index = state.conversations.firstIndex(where: { $0.id == conversation.id }) {
                state.conversations[index] = AskConversation(
                    id: conversation.id, title: trimmed,
                    createdAt: conversation.createdAt, updatedAt: Date())
            }
            toastMessage = .success(String(localized: "Conversation renamed"))
        } catch {
            Logger.error("Failed to rename conversation: \(error)")
            toastMessage = .error(String(localized: "Failed to rename conversation. Please try again."))
        }
    }

    private func mergedConversations(with newConversations: [AskConversation]) -> [AskConversation] {
        state.conversations
            + newConversations.filter { newConversation in
                !state.conversations.contains { $0.id == newConversation.id }
            }
    }
}
