import Foundation
import Combine

@MainActor
final class SourceListViewModel: ObservableObject {
    struct State: Equatable {
        var isLoading = false
        var isLoadingNextPage = false
        var paginationErrorMessage: String?
        var errorMessage: String?
        var allSources: [Source] = []
        var visibleSources: [Source] = []
        var searchQuery = ""
        var selectedFilter: FolioSourceFilter = .all
        var filters: [FolioSourceFilter] = [.all, .files, .web, .text]
        var presentedSheet: Sheet?
        var deleteConfirmationSource: Source?
        var editSource: Source?
        var mutationError: String?
        var toastMessage: ToastMessage?
        var totalCount: Int = 0
        var pagination: SourcePagination?

        enum Sheet: Identifiable, Equatable {
            case addSource
            case editSource(Source)
            case processing(Source)
            case failure(Source)

            var id: String {
                switch self {
                case .addSource: return "addSource"
                case .editSource(let source): return "editSource-\(source.id)"
                case .processing(let source): return "processing-\(source.id)"
                case .failure(let source): return "failure-\(source.id)"
                }
            }
        }
    }

    enum ContentState: Equatable {
        case loading
        case error(String)
        case empty
        case noSearchResults(query: String)
        case loaded([Source])
    }

    @Published private(set) var state = State()
    @Published var editTitle = ""
    @Published var editAuthor = ""
    @Published var isEditing = false
    @Published var isDeleting = false

    var contentState: ContentState {
        if state.isLoading && state.allSources.isEmpty {
            return .loading
        }
        if let error = state.errorMessage, state.allSources.isEmpty {
            return .error(error)
        }
        if state.allSources.isEmpty {
            if !state.searchQuery.isEmpty {
                return .noSearchResults(query: state.searchQuery)
            }
            return .empty
        }
        if state.visibleSources.isEmpty {
            return .noSearchResults(query: state.searchQuery)
        }
        return .loaded(state.visibleSources)
    }

    private let fetchSourcesUseCase: any FetchSourcesUseCaseProtocol
    private let updateSourceUseCase: any UpdateSourceUseCaseProtocol
    let uploadSourceUseCase: any UploadSourceUseCaseProtocol
    let spaceId: String
    private var hasAppeared = false
    private var requestGeneration = 0
    private var searchTask: Task<Void, Never>?

    init(
        spaceId: String,
        fetchSourcesUseCase: any FetchSourcesUseCaseProtocol,
        updateSourceUseCase: any UpdateSourceUseCaseProtocol,
        uploadSourceUseCase: any UploadSourceUseCaseProtocol
    ) {
        self.spaceId = spaceId
        self.fetchSourcesUseCase = fetchSourcesUseCase
        self.updateSourceUseCase = updateSourceUseCase
        self.uploadSourceUseCase = uploadSourceUseCase
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
        case .selectFilter(let filter):
            guard filter != state.selectedFilter else { return }
            state.selectedFilter = filter
            Task { await loadFirstPage() }
        case .addTapped:
            state.presentedSheet = .addSource
        case .dismissSheet:
            state.presentedSheet = nil
            state.mutationError = nil
        case .sourceTapped(let source):
            handleSourceTap(source)
        case .ellipsisTapped(let source):
            editTitle = source.title
            editAuthor = source.author
            state.mutationError = nil
            state.editSource = source
            state.presentedSheet = .editSource(source)
        case .editConfirmed:
            guard !isEditing else { return }
            isEditing = true
            state.mutationError = nil
            invalidateInFlightLoads()
            Task { await performEdit() }
        case .deleteTapped(let source):
            state.editSource = source
            state.deleteConfirmationSource = source
        case .deleteConfirmed:
            guard !isDeleting else { return }
            isDeleting = true
            let source = state.deleteConfirmationSource
            invalidateInFlightLoads()
            Task { await performDelete(source) }
        case .cancelDelete:
            state.deleteConfirmationSource = nil
            state.editSource = nil
        case .retryProcessing(let source):
            state.presentedSheet = nil
            invalidateInFlightLoads()
            Task { await retrySource(source) }
        case .deleteFailedSource(let source):
            state.presentedSheet = nil
            state.deleteConfirmationSource = source
        case .sourceUploaded:
            Task { await loadFirstPage() }
        case .dismissToast:
            state.toastMessage = nil
        }
    }

    enum Intent {
        case appeared
        case retry
        case refresh
        case loadMore
        case searchQueryChanged(String)
        case clearSearch
        case selectFilter(FolioSourceFilter)
        case addTapped
        case dismissSheet
        case sourceTapped(Source)
        case ellipsisTapped(Source)
        case editConfirmed
        case deleteTapped(Source)
        case deleteConfirmed
        case cancelDelete
        case retryProcessing(Source)
        case deleteFailedSource(Source)
        case sourceUploaded
        case dismissToast
    }

    private func handleSourceTap(_ source: Source) {
        switch source.processingState {
        case .ready:
            break
        case .failed:
            state.presentedSheet = .failure(source)
        case .added, .extractingText, .indexingEvidence:
            state.presentedSheet = .processing(source)
        }
    }

    private func invalidateInFlightLoads() {
        requestGeneration += 1
        state.isLoading = false
        state.isLoadingNextPage = false
        searchTask?.cancel()
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
            let query = SourceListQuery(
                spaceId: spaceId,
                sourceType: state.selectedFilter.apiValue,
                search: searchTerm.isEmpty ? nil : searchTerm,
                sort: "recently-added",
                page: nil,
                limit: nil
            )
            Logger.debug("Loading sources for spaceId: \(spaceId)")
            let result = try await fetchSourcesUseCase.execute(query: query)
            guard generation == requestGeneration else { return }
            Logger.debug("Loaded \(result.sources.count) sources")
            replace(with: result)
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch let error as NetworkError {
            guard generation == requestGeneration else { return }
            Logger.error("Failed to load sources: \(error)")
            state.errorMessage = error.localizedDescription
        } catch {
            guard generation == requestGeneration else { return }
            Logger.error("Failed to load sources: \(error)")
            state.errorMessage = error.localizedDescription
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
            let query = SourceListQuery(
                spaceId: spaceId,
                sourceType: state.selectedFilter.apiValue,
                search: searchTerm.isEmpty ? nil : searchTerm,
                sort: "recently-added",
                page: pagination.page + 1,
                limit: pagination.limit
            )
            let result = try await fetchSourcesUseCase.execute(query: query)
            guard generation == requestGeneration else { return }
            append(result)
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            guard generation == requestGeneration else { return }
            Logger.error("Failed to load next page: \(error)")
            state.paginationErrorMessage = error.localizedDescription
        }
    }

    private func replace(with result: SourceListResult) {
        state.allSources = result.sources.sorted { $0.createdAt > $1.createdAt }
        state.pagination = result.pagination
        state.totalCount = result.pagination?.totalCount ?? result.sources.count
        applyFilter()
    }

    private func append(_ result: SourceListResult) {
        var existingIDs = Set(state.allSources.map(\.id))
        let newSources = result.sources.filter { source in
            guard existingIDs.insert(source.id).inserted else { return false }
            return true
        }
        state.allSources.append(contentsOf: newSources)
        state.allSources.sort { $0.createdAt > $1.createdAt }
        state.pagination = result.pagination
        state.totalCount = result.pagination?.totalCount ?? state.allSources.count
        applyFilter()
    }

    private func applyFilter() {
        state.visibleSources = state.allSources.sorted { $0.createdAt > $1.createdAt }
    }

    private func performEdit() async {
        guard let source = state.editSource, let sheet = state.presentedSheet,
              case .editSource = sheet else {
            isEditing = false
            return
        }
        let newTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let newAuthor = editAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else {
            state.mutationError = String(localized: "Title cannot be empty")
            isEditing = false
            return
        }
        do {
            let updated = try await updateSourceUseCase.execute(id: source.id, title: newTitle, author: newAuthor)
            Logger.debug("Source updated: \(updated.title)")
            if let index = state.allSources.firstIndex(where: { $0.id == source.id }) {
                state.allSources[index] = updated
                applyFilter()
            }
            state.presentedSheet = nil
            state.toastMessage = .success(String(localized: "Source updated"))
        } catch {
            Logger.error("Failed to update source: \(error)")
            state.mutationError = error.localizedDescription
        }
        isEditing = false
    }

    private func performDelete(_ source: Source?) async {
        guard let source else {
            isDeleting = false
            return
        }
        do {
            try await uploadSourceUseCase.deleteSource(id: source.id)
            state.allSources.removeAll { $0.id == source.id }
            state.totalCount = max(0, state.totalCount - 1)
            applyFilter()
            state.toastMessage = .success(String(localized: "Source deleted"))
        } catch {
            state.toastMessage = .error(error.localizedDescription)
        }
        state.deleteConfirmationSource = nil
        state.editSource = nil
        isDeleting = false
    }

    private func retrySource(_ source: Source) async {
        do {
            _ = try await uploadSourceUseCase.retrySource(id: source.id)
            if let index = state.allSources.firstIndex(where: { $0.id == source.id }) {
                state.allSources[index] = state.allSources[index].withProcessingState(.added)
                applyFilter()
            }
            state.presentedSheet = .processing(state.allSources.first { $0.id == source.id } ?? source)
            state.toastMessage = .success(String(localized: "Processing retried"))
        } catch {
            state.toastMessage = .error(error.localizedDescription)
        }
    }

    func refresh() async {
        await loadFirstPage()
    }

    var didTapReadySource: Source? {
        nil
    }
}

extension Date {
    var addedRelativeLabel: String {
        let calendar = Calendar.current
        let now = Date()
        let minutes = max(0, Int(now.timeIntervalSince(self) / 60))
        if minutes < 3 { return String(localized: "Just now") }
        if calendar.isDateInToday(self) { return String(localized: "Today") }
        if calendar.isDateInYesterday(self) { return String(localized: "Yesterday") }
        if let daysAgo = calendar.dateComponents([.day], from: self, to: now).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: self)
        }
        let thisYear = calendar.component(.year, from: now)
        let dateYear = calendar.component(.year, from: self)
        let formatter = DateFormatter()
        if dateYear == thisYear {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d yyyy"
        }
        return formatter.string(from: self)
    }
}
