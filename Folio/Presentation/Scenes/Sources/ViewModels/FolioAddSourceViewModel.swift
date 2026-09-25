import Foundation
import Combine
import UniformTypeIdentifiers
import PDFKit

@MainActor
final class FolioAddSourceViewModel: ViewModelProtocol {

    enum AddSourceTab: String, CaseIterable, Identifiable {
        case files, web, text
        var id: String { rawValue }
        var title: String {
            switch self {
            case .files: return String(localized: "File")
            case .web: return String(localized: "Web")
            case .text: return String(localized: "Text")
            }
        }
    }

    enum ProcessingStage: String, CaseIterable {
        case added, extractText, indexEvidence, ready
        var title: String {
            switch self {
            case .added: return String(localized: "Added")
            case .extractText: return String(localized: "Extract text")
            case .indexEvidence: return String(localized: "Index evidence")
            case .ready: return String(localized: "Ready")
            }
        }
    }

    enum StageStatus: Equatable { case pending, active, completed, failed }

    static let supportedExtensions = ["pdf", "docx", "txt", "md", "pptx", "xlsx", "csv", "epub"]
    static let maxFileSize: Int64 = 50_000_000
    static let manualContentMax = 100_000
    static let manualContentMin = 10
    static let titleMax = 255
    static let authorMax = 100

    static var manualContentMinError: String {
        String.localizedStringWithFormat(
            String(localized: "Content must be at least %lld characters long."),
            Int64(manualContentMin)
        )
    }

    static var manualContentMaxError: String {
        String.localizedStringWithFormat(
            String(localized: "Content exceeds maximum limit of %lld characters."),
            Int64(manualContentMax)
        )
    }

    struct State {
        var selectedTab: AddSourceTab = .files
        var isSubmitting = false
        var isProcessing = false
        var processingProgress: Double = 0
        var processingStages: [(stage: ProcessingStage, status: StageStatus)] = []
        var processingSourceID: String?
        var processingSourceTitle: String = ""
        var processingSource: Source? = nil
        var processingStageLabel: String = ""
        var isProcessingComplete = false
        var isProcessingFailed = false
        var submitError: String?
        var deletionError: String?

        var selectedFileURL: URL?
        var selectedFileName: String = ""
        var selectedFileSize: Int64 = 0
        var selectedFilePageCount: Int?
        var fileError: String?

        var webURL: String = ""
        var webTitle: String = ""
        var webAuthor: String = ""
        var webURLError: String?

        var manualTitle: String = ""
        var manualAuthor: String = ""
        var manualContent: String = ""
        var manualContentError: String?

        var showDeleteConfirmation = false
        var showCancelProcessingConfirmation = false
        var isAddingNewSource = true
        var shouldDismiss = false
    }

    enum Action {
        case selectTab(AddSourceTab), fileSelected(URL?), removeFile
        case webURLChanged(String), webTitleChanged(String), webAuthorChanged(String)
        case manualTitleChanged(String), manualAuthorChanged(String), manualContentChanged(String)
        case addSource, openSource, openAsk, showAddForm
        case retryProcessing, deleteSourceTapped, deleteSourceConfirmed, dismissDeleteConfirmation
        case cancelProcessingTapped, confirmCancelProcessing, dismissCancelProcessing
    }

    @Published private(set) var state = State()

    var onOpenSource: ((Source) -> Void)?
    var onOpenAsk: ((Source) -> Void)?
    var onProcessingComplete: ((Source) -> Void)?
    var onSourceOperationFailed: ((String) -> Void)?

    private let uploadUseCase: any UploadSourceUseCaseProtocol
    let spaceId: String
    private var uploadTask: Task<Void, Never>?
    private var statusStreamTask: Task<Void, Never>?
    private var activeSessionID: UUID?
    private var detachedUploadTasks: [UUID: Task<Void, Never>] = [:]
    private var detachedStatusTasks: [UUID: Task<Void, Never>] = [:]
    private var deleteTasks: [String: Task<Void, Never>] = [:]
    private var pendingDismissDeletes: Set<String> = []
    private var pageCountTask: Task<Void, Never>?
    private var isFileAccessing = false
    private var formScopedURL: URL?
    private var detachedScopedURLs: [UUID: URL] = [:]

    init(uploadUseCase: any UploadSourceUseCaseProtocol, spaceId: String) {
        self.uploadUseCase = uploadUseCase
        self.spaceId = spaceId
    }

    deinit {
        uploadTask?.cancel()
        statusStreamTask?.cancel()
        for task in detachedUploadTasks.values { task.cancel() }
        for task in detachedStatusTasks.values { task.cancel() }
        for task in deleteTasks.values { task.cancel() }
        pageCountTask?.cancel()
        formScopedURL?.stopAccessingSecurityScopedResource()
        for url in detachedScopedURLs.values { url.stopAccessingSecurityScopedResource() }
    }

    var isSubmitEnabled: Bool {
        switch state.selectedTab {
        case .files: return state.selectedFileURL != nil && state.fileError == nil
        case .web: return validWebURL
        case .text: return validManualContent
        }
    }

    var canCancelProcessing: Bool {
        state.processingSourceID != nil
    }

    private var validWebURL: Bool {
        guard !state.webURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let url = URL(string: state.webURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host != nil else { return false }
        return true
    }

    private var validManualContent: Bool {
        let count = state.manualContent.count
        return count >= Self.manualContentMin && count <= Self.manualContentMax
    }

    func handle(_ action: Action) {
        switch action {
        case .selectTab(let tab): state.selectedTab = tab

        case .fileSelected(let url):
            guard let url else { return }
            let ext = url.pathExtension.lowercased()
            guard Self.supportedExtensions.contains(ext) else {
                stopFileAccess()
                state.fileError = String(localized: "Unsupported file format. Please upload supported files (.pdf, .docx, .txt, .md, .pptx, .xlsx, .csv, .epub).")
                state.selectedFileURL = nil; state.selectedFileName = ""; state.selectedFileSize = 0; state.selectedFilePageCount = nil
                return
            }

            stopFileAccess()

            guard url.startAccessingSecurityScopedResource() else {
                state.fileError = String(localized: "Unable to access the selected file.")
                return
            }

            do {
                guard let rawSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                    url.stopAccessingSecurityScopedResource()
                    state.fileError = String(localized: "Unable to access the selected file.")
                    return
                }
                let size = Int64(rawSize)
                guard size <= Self.maxFileSize else {
                    url.stopAccessingSecurityScopedResource()
                    state.fileError = String(localized: "File size exceeds 50 MB limit. Please select a smaller file.")
                    return
                }
                isFileAccessing = true
                formScopedURL = url
                state.selectedFileURL = url
                state.selectedFileName = url.lastPathComponent
                state.selectedFileSize = size
                state.selectedFilePageCount = nil
                state.fileError = nil
                loadPageCount(for: url)
            } catch {
                url.stopAccessingSecurityScopedResource()
                state.fileError = String(localized: "Unable to access the selected file.")
            }

        case .removeFile:
            stopFileAccess()
            state.selectedFileURL = nil; state.selectedFileName = ""; state.selectedFileSize = 0; state.selectedFilePageCount = nil; state.fileError = nil

        case .webURLChanged(let value):
            state.webURL = value
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                state.webURLError = nil
            } else if !validWebURL {
                state.webURLError = String(localized: "Please enter a valid URL")
            } else {
                state.webURLError = nil
            }

        case .webTitleChanged(let value): if value.count <= Self.titleMax { state.webTitle = value }
        case .webAuthorChanged(let value): if value.count <= Self.authorMax { state.webAuthor = value }
        case .manualTitleChanged(let value): if value.count <= Self.titleMax { state.manualTitle = value }
        case .manualAuthorChanged(let value): if value.count <= Self.authorMax { state.manualAuthor = value }

        case .manualContentChanged(let value):
            if value.count <= Self.manualContentMax {
                state.manualContent = value
            }
            if state.manualContent.isEmpty {
                state.manualContentError = nil
            } else if state.manualContent.count < Self.manualContentMin {
                state.manualContentError = Self.manualContentMinError
            } else {
                state.manualContentError = nil
            }

        case .addSource:
            guard !state.isSubmitting, validateForSubmit() else { return }
            state.isAddingNewSource = false
            state.isSubmitting = true
            state.submitError = nil
            let session = beginSession()
            uploadTask = Task { [weak self] in
                await self?.performUpload(session: session)
            }

        // Detaches instead of cancelling, so a previously in-flight upload
        // keeps running while the user adds another source; its completion
        // only refreshes the source list via onProcessingComplete.
        case .showAddForm:
            let hasActiveTasks = uploadTask != nil || statusStreamTask != nil
            detachProcessingSession()
            if hasActiveTasks {
                resetState()
            } else {
                resetProcessingState()
            }
        case .openSource: break
        case .openAsk: break

        case .retryProcessing:
            guard !state.isSubmitting, let sourceID = state.processingSourceID else { return }
            state.isSubmitting = true
            state.submitError = nil
            statusStreamTask?.cancel()
            statusStreamTask = nil
            let session = beginSession()
            uploadTask = Task { [weak self] in
                guard let self else { return }
                defer { self.finishUploadSession(session) }
                do {
                    let source = try await self.uploadUseCase.retrySource(id: sourceID)
                    guard !Task.isCancelled else { return }
                    self.beginProcessing(session: session, source: source)
                } catch {
                    guard !Task.isCancelled else { return }
                    if session == self.activeSessionID {
                        self.state.submitError = error.localizedDescription
                    } else {
                        self.onSourceOperationFailed?(error.localizedDescription)
                    }
                }
            }

        case .deleteSourceTapped: state.showDeleteConfirmation = true
        case .deleteSourceConfirmed:
            state.showDeleteConfirmation = false
            let sourceID = state.processingSourceID
            stopProcessing()
            if let sourceID {
                deleteSource(id: sourceID, shouldDismiss: true)
            } else {
                resetState()
                state.shouldDismiss = true
            }
        case .dismissDeleteConfirmation: state.showDeleteConfirmation = false

        case .cancelProcessingTapped:
            guard canCancelProcessing else { return }
            state.showCancelProcessingConfirmation = true
        case .confirmCancelProcessing:
            state.showCancelProcessingConfirmation = false
            let sourceID = state.processingSourceID
            let wasProcessingComplete = state.isProcessingComplete
            stopProcessing()
            // Return to the add form immediately; the delete runs in the
            // background and reports any failure through onSourceOperationFailed.
            if let sourceID, !wasProcessingComplete {
                deleteSource(id: sourceID, shouldDismiss: false)
            }
            resetState()
        case .dismissCancelProcessing:
            state.showCancelProcessingConfirmation = false
        }
    }

    private func validateForSubmit() -> Bool {
        switch state.selectedTab {
        case .files:
            guard state.selectedFileURL != nil else { state.fileError = String(localized: "Please select a file to add"); return false }
            return true
        case .web:
            guard !state.webURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { state.webURLError = String(localized: "Please enter a valid URL"); return false }
            guard validWebURL else { state.webURLError = String(localized: "Please enter a valid URL"); return false }
            return true
        case .text:
            let count = state.manualContent.count
            guard count >= Self.manualContentMin else { state.manualContentError = Self.manualContentMinError; return false }
            guard count <= Self.manualContentMax else { state.manualContentError = Self.manualContentMaxError; return false }
            return true
        }
    }

    private func performUpload(session: UUID) async {
        defer { finishUploadSession(session) }
        guard session == activeSessionID else { return }
        state.submitError = nil
        let title = resolvedTitle()
        let author = resolvedAuthor()

        let source: Source
        do {
            source = try await {
                switch state.selectedTab {
                case .files:
                    guard let url = state.selectedFileURL else { throw CancellationError() }
                    return try await uploadUseCase.uploadFile(spaceId: spaceId, fileURL: url, title: title, author: author)
                case .web:
                    return try await uploadUseCase.uploadWeb(spaceId: spaceId, url: state.webURL.trimmingCharacters(in: .whitespacesAndNewlines), title: title, author: author)
                case .text:
                    return try await uploadUseCase.uploadManual(spaceId: spaceId, content: state.manualContent, title: title, author: author)
                }
            }()
            stopFileAccess(for: session)
        } catch is CancellationError {
            stopFileAccess(for: session)
            return
        } catch {
            stopFileAccess(for: session)
            guard !Task.isCancelled else { return }
            if session == activeSessionID {
                state.submitError = error.localizedDescription
            } else {
                onSourceOperationFailed?(error.localizedDescription)
            }
            return
        }

        guard !Task.isCancelled else { return }
        beginProcessing(session: session, source: source)
    }

    private func beginProcessing(session: UUID, source: Source) {
        guard session == activeSessionID else {
            switch source.processingState {
            case .ready, .failed:
                onProcessingComplete?(source)
            default:
                startSSEProgress(session: session, source: source)
            }
            return
        }

        state.processingSourceID = source.id
        state.processingSourceTitle = source.title
        state.processingSource = source

        state.isProcessing = true
        state.isProcessingComplete = false
        state.isProcessingFailed = false
        state.processingProgress = 0
        state.processingStages = ProcessingStage.allCases.map { ($0, .pending) }
        updateStage(0, status: .active)

        switch source.processingState {
        case .ready:
            finishProcessing(success: true)
        case .failed:
            finishProcessing(success: false)
        default:
            startSSEProgress(session: session, source: source)
        }
    }

    private func startSSEProgress(session: UUID, source: Source) {
        let sourceID = source.id
        Logger.debug("Starting SSE stream for source: \(sourceID)")

        let stream = uploadUseCase.sourceStatusStream()

        let task = Task { [weak self] in
            var receivedTerminalEvent = false
            do {
                for try await event in stream {
                    guard !Task.isCancelled else { return }
                    guard event.sourceId == sourceID else { continue }

                    if event.state == "ready" || event.state == "failed" {
                        receivedTerminalEvent = true
                    }

                    guard let self else { return }
                    if session == self.activeSessionID {
                        self.applyStatusEvent(event)
                    } else if receivedTerminalEvent {
                        self.onProcessingComplete?(source.withProcessingState(event.state == "ready" ? .ready : .failed))
                        self.detachedStatusTasks[session] = nil
                        return
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    Logger.debug("SSE stream ended: \(error)")
                }
            }
            guard let self else { return }
            if !receivedTerminalEvent, !Task.isCancelled {
                if session == self.activeSessionID {
                    self.finishProcessing(success: false)
                } else {
                    // Detached stream dropped before a terminal event; refresh
                    // the list so it reconciles with the server's actual state.
                    self.onProcessingComplete?(source)
                }
            }
            if session != self.activeSessionID {
                self.detachedStatusTasks[session] = nil
            }
        }
        if session == activeSessionID {
            statusStreamTask = task
        } else {
            detachedStatusTasks[session] = task
        }
    }

    private func applyStatusEvent(_ event: SourceStatusEvent) {
        let stageIndex = stageIndexForState(event.state)
        let progress = Double(event.progress) / 100.0

        state.processingProgress = progress

        for i in 0..<ProcessingStage.allCases.count {
            if i < stageIndex { updateStage(i, status: .completed) }
            else if i == stageIndex {
                if event.state == "failed" {
                    updateStage(i, status: .failed)
                } else {
                    updateStage(i, status: .active)
                }
            }
        }

        if event.state == "ready" {
            state.processingSource = state.processingSource?.withProcessingState(.ready)
            finishProcessing(success: true)
        } else if event.state == "failed" {
            state.processingSource = state.processingSource?.withProcessingState(.failed)
            finishProcessing(success: false)
        }
    }

    private func stageIndexForState(_ state: String) -> Int {
        switch state {
        case "added": return 0
        case "extracting_text": return 1
        case "indexing_evidence": return 2
        case "ready", "failed": return 3
        default: return 0
        }
    }

    private func finishProcessing(success: Bool) {
        statusStreamTask?.cancel()
        statusStreamTask = nil
        state.showCancelProcessingConfirmation = false
        if success {
            state.isProcessingComplete = true
            state.isProcessingFailed = false
            state.processingStageLabel = ProcessingStage.ready.title
            for i in 0..<ProcessingStage.allCases.count { updateStage(i, status: .completed) }
            if let source = state.processingSource {
                onProcessingComplete?(source)
            }
        } else {
            state.isProcessingFailed = true
            state.isProcessingComplete = false
            state.processingStageLabel = String(localized: "Failed")
            state.processingProgress = 0
            for i in 0..<ProcessingStage.allCases.count { updateStage(i, status: .failed) }
        }
    }

    private func updateStage(_ index: Int, status: StageStatus) {
        guard index < state.processingStages.count else { return }
        var stages = state.processingStages
        stages[index].status = status
        state.processingStages = stages
        if status == .active || status == .completed { state.processingStageLabel = stages[index].stage.title }
    }

    private func resolvedTitle() -> String {
        switch state.selectedTab {
        case .files: return state.selectedFileName.isEmpty ? String(localized: "Untitled Source") : state.selectedFileName
        case .web:
            let t = state.webTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
            if let host = URL(string: state.webURL.trimmingCharacters(in: .whitespacesAndNewlines))?.host { return host }
            return String(localized: "Untitled Source")
        case .text:
            let t = state.manualTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? String(localized: "Untitled Source") : t
        }
    }

    private func resolvedAuthor() -> String {
        switch state.selectedTab {
        case .files: return ""
        case .web: return state.webAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        case .text: return state.manualAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func beginSession() -> UUID {
        let session = UUID()
        activeSessionID = session
        return session
    }

    private func finishUploadSession(_ session: UUID) {
        if session == activeSessionID {
            state.isSubmitting = false
            uploadTask = nil
        } else {
            detachedUploadTasks[session] = nil
            detachedScopedURLs.removeValue(forKey: session)?.stopAccessingSecurityScopedResource()
        }
    }

    private func detachProcessingSession() {
        guard let session = activeSessionID else { return }
        if let uploadTask { detachedUploadTasks[session] = uploadTask }
        if let statusStreamTask { detachedStatusTasks[session] = statusStreamTask }
        if uploadTask != nil, isFileAccessing, let url = formScopedURL {
            detachedScopedURLs[session] = url
            isFileAccessing = false
            formScopedURL = nil
        }
        activeSessionID = nil
        uploadTask = nil
        statusStreamTask = nil
    }

    private func stopProcessing() {
        uploadTask?.cancel(); uploadTask = nil
        statusStreamTask?.cancel(); statusStreamTask = nil
        activeSessionID = nil
        state.isSubmitting = false
        stopFileAccess()
    }

    private func deleteSource(id: String, shouldDismiss: Bool) {
        if shouldDismiss { pendingDismissDeletes.insert(id) }
        guard deleteTasks[id] == nil else { return }
        deleteTasks[id] = Task { [weak self] in
            guard let self else { return }
            defer { self.deleteTasks[id] = nil }
            do {
                try await self.uploadUseCase.deleteSource(id: id)
                let shouldDismiss = self.pendingDismissDeletes.remove(id) != nil
                if self.state.processingSourceID == id {
                    self.finishDelete(id: id, shouldDismiss: shouldDismiss)
                } else if shouldDismiss {
                    self.state.shouldDismiss = true
                }
            } catch {
                self.pendingDismissDeletes.remove(id)
                if self.state.processingSourceID == id {
                    self.state.deletionError = error.localizedDescription
                } else {
                    self.onSourceOperationFailed?(error.localizedDescription)
                }
            }
        }
    }

    private func finishDelete(id: String, shouldDismiss: Bool) {
        guard state.processingSourceID == id else { return }
        resetState()
        if shouldDismiss { state.shouldDismiss = true }
    }

    private func resetState() { stopFileAccess(); state = State() }

    private func resetProcessingState() {
        stopFileAccess()
        state.isAddingNewSource = true
        state.isProcessing = false
        state.isProcessingComplete = false
        state.isProcessingFailed = false
        state.processingProgress = 0
        state.processingStages = []
        state.processingSourceID = nil
        state.processingSource = nil
        state.processingStageLabel = ""
        state.isSubmitting = false
        state.submitError = nil
        state.deletionError = nil
        state.showDeleteConfirmation = false
        state.showCancelProcessingConfirmation = false
        state.shouldDismiss = false
        state.selectedFileURL = nil
        state.selectedFileName = ""
        state.selectedFileSize = 0
        state.selectedFilePageCount = nil
        state.fileError = nil
    }

    private func loadPageCount(for url: URL) {
        pageCountTask = Task.detached(priority: .userInitiated) { [weak self] in
            let count = PDFDocument(url: url)?.pageCount
            guard let self else { return }
            await self.setPageCount(count, for: url)
        }
    }

    private func setPageCount(_ count: Int?, for url: URL) {
        guard state.selectedFileURL == url else { return }
        state.selectedFilePageCount = count
    }

    private func stopFileAccess(for session: UUID) {
        guard session == activeSessionID else { return }
        stopFileAccess()
    }

    private func stopFileAccess() {
        pageCountTask?.cancel()
        pageCountTask = nil
        guard isFileAccessing else { return }
        isFileAccessing = false
        formScopedURL?.stopAccessingSecurityScopedResource()
        formScopedURL = nil
    }
}

extension Int64 {
    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
