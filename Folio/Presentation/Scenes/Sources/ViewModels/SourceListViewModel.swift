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
        var sortOption = SourceSortOption.recentlyAdded
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
            case sortOptions

            var id: String {
                switch self {
                case .addSource: return "addSource"
                case .editSource(let source): return "editSource-\(source.id)"
                case .processing(let source): return "processing-\(source.id)"
                case .failure(let source): return "failure-\(source.id)"
                case .sortOptions: return "sortOptions"
                }
            }
        }
    }

    enum ContentState: Equatable {
        case loading
        case error(String)
        case empty
        case noSearchResults
        case loaded([Source])
    }

    @Published private(set) var state = State()
    @Published var editTitle = ""
    @Published var editAuthor = ""
    @Published var editContent = ""
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
                return .noSearchResults
            }
            return .empty
        }
        if state.visibleSources.isEmpty {
            return .noSearchResults
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
        case .sourceStatusChanged(let source):
            invalidateInFlightLoads()
            if let index = state.allSources.firstIndex(where: { $0.id == source.id }) {
                state.allSources[index] = source
                applyFilter()
            }
        case .sourceDeletedFromProcessing(let source):
            invalidateInFlightLoads()
            state.presentedSheet = nil
            state.allSources.removeAll { $0.id == source.id }
            state.totalCount = max(0, state.totalCount - 1)
            applyFilter()
            state.toastMessage = .success(String(localized: "Source deleted"))
        case .ellipsisTapped(let source):
            editTitle = source.title
            editAuthor = source.author
            editContent = source.content
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
            state.deleteConfirmationSource = nil
            state.editSource = nil
            invalidateInFlightLoads()
            Task { await performDelete(source) }
        case .cancelDelete:
            state.deleteConfirmationSource = nil
            state.editSource = nil
        case .sourceUploaded:
            Task { await loadFirstPage() }
        case .sourceCreated(let source):
            invalidateInFlightLoads()
            if !state.allSources.contains(where: { $0.id == source.id }) {
                state.allSources.insert(source, at: 0)
                state.totalCount += 1
                applyFilter()
            }
        case .sortTapped:
            state.presentedSheet = .sortOptions
        case .sortSelected(let option):
            guard option != state.sortOption else {
                state.presentedSheet = nil
                return
            }
            state.sortOption = option
            state.presentedSheet = nil
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
        case sourceStatusChanged(Source)
        case sourceDeletedFromProcessing(Source)
        case ellipsisTapped(Source)
        case editConfirmed
        case deleteTapped(Source)
        case deleteConfirmed
        case cancelDelete
        case sourceUploaded
        case sourceCreated(Source)
        case sortTapped
        case sortSelected(SourceSortOption)
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
                sort: state.sortOption,
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
                sort: state.sortOption,
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
        state.allSources = sortedSources(result.sources)
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
        state.allSources = sortedSources(state.allSources)
        state.pagination = result.pagination
        state.totalCount = result.pagination?.totalCount ?? state.allSources.count
        applyFilter()
    }

    private func applyFilter() {
        state.visibleSources = sortedSources(state.allSources)
    }

    private func sortedSources(_ sources: [Source]) -> [Source] {
        switch state.sortOption {
        case .recentlyAdded:
            return sources.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.id < rhs.id
            }
        case .recentlyUpdated:
            return sources.sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.id < rhs.id
            }
        case .alphabeticalAZ:
            return sources.sorted { sourceComesBefore($0, $1, ascending: true) }
        case .alphabeticalZA:
            return sources.sorted { sourceComesBefore($0, $1, ascending: false) }
        }
    }

    private func sourceComesBefore(_ lhs: Source, _ rhs: Source, ascending: Bool) -> Bool {
        let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        guard titleComparison != .orderedSame else { return lhs.id < rhs.id }
        return ascending
            ? titleComparison == .orderedAscending
            : titleComparison == .orderedDescending
    }

    private func performEdit() async {
        guard let source = state.editSource, let sheet = state.presentedSheet,
              case .editSource = sheet else {
            isEditing = false
            return
        }
        let newTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let newAuthor = editAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        let newContent = editContent
        guard !newTitle.isEmpty else {
            state.mutationError = String(localized: "Title cannot be empty")
            isEditing = false
            return
        }
        do {
            let updated = try await updateSourceUseCase.execute(id: source.id, title: newTitle, author: newAuthor, content: newContent.isEmpty ? nil : newContent)
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

    func refresh() async {
        let refreshTask = Task { await loadFirstPage() }
        await refreshTask.value
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
        if minutes < 1 { return String(localized: "Added just now") }
        if minutes < 60 { return String(localized: "Added \(minutes)m ago") }
        let hours = minutes / 60
        if hours < 24 { return String(localized: "Added \(hours)h ago") }
        let days = hours / 24
        if days < 7 { return String(localized: "Added \(days)d ago") }
        if days < 30 { return String(localized: "Added \(days / 7)w ago") }
        if days < 365 { return String(localized: "Added \(days / 30)mo ago") }
        return String(localized: "Added \(days / 365)y ago")
    }
}
