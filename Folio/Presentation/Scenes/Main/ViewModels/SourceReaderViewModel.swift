import Foundation
import Combine

@MainActor
final class SourceReaderViewModel: ObservableObject {
    struct State: Equatable {
        var isLoading = false
        var errorMessage: String?
        var source: Source?
        var isEditing = false
        var editTitle = ""
        var editAuthor = ""
        var editError: String?
        var showEditSheet = false
        var showDeleteConfirmation = false
        var isDeleting = false
        var previewUrl: URL?
        var showShareSheet = false
        var toastMessage: ToastMessage?
    }

    @Published private(set) var state = State()

    private let initialSource: Source
    private let fetchSourceDetailUseCase: any FetchSourceDetailUseCaseProtocol
    private let updateSourceUseCase: any UpdateSourceUseCaseProtocol
    private let uploadSourceUseCase: any UploadSourceUseCaseProtocol
    private let fetchSourcePreviewUseCase: any FetchSourcePreviewUseCaseProtocol

    private let onAskSource: ((Source) -> Void)?
    private let onDeleted: ((Source) -> Void)?

    private var hasAppeared = false
    private var detailLoadGeneration = 0

    init(
        source: Source,
        fetchSourceDetailUseCase: any FetchSourceDetailUseCaseProtocol,
        updateSourceUseCase: any UpdateSourceUseCaseProtocol,
        uploadSourceUseCase: any UploadSourceUseCaseProtocol,
        fetchSourcePreviewUseCase: any FetchSourcePreviewUseCaseProtocol,
        onAskSource: ((Source) -> Void)? = nil,
        onDeleted: ((Source) -> Void)? = nil
    ) {
        self.initialSource = source
        self.fetchSourceDetailUseCase = fetchSourceDetailUseCase
        self.updateSourceUseCase = updateSourceUseCase
        self.uploadSourceUseCase = uploadSourceUseCase
        self.fetchSourcePreviewUseCase = fetchSourcePreviewUseCase
        self.onAskSource = onAskSource
        self.onDeleted = onDeleted
        state.source = source
    }

    var source: Source {
        state.source ?? initialSource
    }

    enum Intent {
        case appeared
        case retry
        case editTapped
        case editTitleChanged(String)
        case editAuthorChanged(String)
        case cancelEdit
        case editConfirmed
        case deleteTapped
        case cancelDelete
        case deleteConfirmed
        case askThisSource
        case openOriginalTapped
        case dismissShareSheet
        case dismissToast
    }

    func send(_ intent: Intent) {
        switch intent {
        case .appeared:
            guard !hasAppeared else { return }
            hasAppeared = true
            Task { await loadDetail() }
        case .retry:
            Task { await loadDetail() }
        case .editTapped:
            state.editTitle = source.title
            state.editAuthor = source.author
            state.editError = nil
            state.showEditSheet = true
        case .editTitleChanged(let value):
            state.editTitle = value
        case .editAuthorChanged(let value):
            state.editAuthor = value
        case .cancelEdit:
            state.showEditSheet = false
            state.editError = nil
        case .editConfirmed:
            guard !state.isEditing else { return }
            let title = state.editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                state.editError = String(localized: "Title cannot be empty")
                return
            }
            state.isEditing = true
            state.editError = nil
            Task { await performEdit(title: title) }
        case .deleteTapped:
            state.showDeleteConfirmation = true
        case .cancelDelete:
            state.showDeleteConfirmation = false
        case .deleteConfirmed:
            guard !state.isDeleting else { return }
            state.isDeleting = true
            state.showDeleteConfirmation = false
            Task { await performDelete() }
        case .askThisSource:
            onAskSource?(source)
        case .openOriginalTapped:
            Task { await loadPreview() }
        case .dismissShareSheet:
            state.showShareSheet = false
        case .dismissToast:
            state.toastMessage = nil
        }
    }

    private func loadDetail() async {
        detailLoadGeneration += 1
        let generation = detailLoadGeneration
        state.isLoading = true
        state.errorMessage = nil
        defer {
            if generation == detailLoadGeneration {
                state.isLoading = false
            }
        }
        do {
            let detail = try await fetchSourceDetailUseCase.execute(id: initialSource.id)
            guard generation == detailLoadGeneration else { return }
            Logger.debug("Loaded source detail for \(detail.id)")
            state.source = detail
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            guard generation == detailLoadGeneration else { return }
            Logger.error("Failed to load source detail: \(error)")
            state.errorMessage = error.localizedDescription
        }
    }

    private func performEdit(title: String) async {
        defer { state.isEditing = false }
        let author = state.editAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let updated = try await updateSourceUseCase.execute(id: source.id, title: title, author: author)
            Logger.debug("Source updated: \(updated.title)")
            state.source = updated.withStructuredContent(updated.structuredContent ?? state.source?.structuredContent)
            state.showEditSheet = false
            state.editError = nil
            state.toastMessage = .success(String(localized: "Source updated"))
        } catch {
            Logger.error("Failed to update source: \(error)")
            state.editError = error.localizedDescription
        }
    }

    private func performDelete() async {
        defer { state.isDeleting = false }
        do {
            try await uploadSourceUseCase.deleteSource(id: source.id)
            Logger.debug("Source deleted: \(source.id)")
            onDeleted?(source)
        } catch {
            Logger.error("Failed to delete source: \(error)")
            state.toastMessage = .error(error.localizedDescription)
        }
    }

    private func loadPreview() async {
        do {
            let preview = try await fetchSourcePreviewUseCase.execute(source: source)
            guard let url = preview.urlValue else {
                state.toastMessage = .error(String(localized: "This source cannot be opened."))
                return
            }
            state.previewUrl = url
            state.showShareSheet = true
        } catch {
            Logger.error("Failed to load preview: \(error)")
            state.toastMessage = .error(error.localizedDescription)
        }
    }
}
