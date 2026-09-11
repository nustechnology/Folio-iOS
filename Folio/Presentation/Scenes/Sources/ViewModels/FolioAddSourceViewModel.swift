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
        var shouldDismiss = false
    }

    enum Action {
        case selectTab(AddSourceTab), fileSelected(URL?), removeFile
        case webURLChanged(String), webTitleChanged(String), webAuthorChanged(String)
        case manualTitleChanged(String), manualAuthorChanged(String), manualContentChanged(String)
        case addSource, dismissProcessing, openSource, openAsk, resetToAddForm
        case retryProcessing, deleteSourceTapped, deleteSourceConfirmed, dismissDeleteConfirmation
    }

    @Published private(set) var state = State()

    var onOpenSource: ((Source) -> Void)?
    var onOpenAsk: ((Source) -> Void)?
    var onProcessingComplete: ((Source) -> Void)?

    private let uploadUseCase: any UploadSourceUseCaseProtocol
    private let spaceId: String
    private var uploadTask: Task<Void, Never>?
    private var statusStreamTask: Task<Void, Never>?
    private var pageCountTask: Task<Void, Never>?
    private var isFileAccessing = false

    init(uploadUseCase: any UploadSourceUseCaseProtocol, spaceId: String) {
        self.uploadUseCase = uploadUseCase
        self.spaceId = spaceId
    }

    var isSubmitEnabled: Bool {
        switch state.selectedTab {
        case .files: return state.selectedFileURL != nil
        case .web: return validWebURL
        case .text: return validManualContent
        }
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

        case .webURLChanged(let v): state.webURL = v; state.webURLError = nil
        case .webTitleChanged(let v): if v.count <= Self.titleMax { state.webTitle = v }
        case .webAuthorChanged(let v): if v.count <= Self.authorMax { state.webAuthor = v }
        case .manualTitleChanged(let v): if v.count <= Self.titleMax { state.manualTitle = v }
        case .manualAuthorChanged(let v): if v.count <= Self.authorMax { state.manualAuthor = v }
        case .manualContentChanged(let v): if v.count <= Self.manualContentMax { state.manualContent = v }; state.manualContentError = nil

        case .addSource:
            guard !state.isSubmitting, validateForSubmit() else { return }
            state.isSubmitting = true
            state.submitError = nil
            uploadTask = Task { await performUpload() }

        case .dismissProcessing: stopProcessing(); resetState()
        case .resetToAddForm: stopProcessing(); resetState()
        case .openSource: break
        case .openAsk: break

        case .retryProcessing:
            guard !state.isSubmitting, let sourceID = state.processingSourceID else { return }
            state.isSubmitting = true
            state.submitError = nil
            uploadTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let source = try await self.uploadUseCase.retrySource(id: sourceID)
                    self.state.isProcessingFailed = false
                    self.state.isProcessingComplete = false
                    self.state.processingProgress = 0
                    self.state.processingStageLabel = ""
                    self.beginProcessing(for: source)
                } catch {
                    self.state.submitError = error.localizedDescription
                }
                self.state.isSubmitting = false
            }

        case .deleteSourceTapped: state.showDeleteConfirmation = true
        case .deleteSourceConfirmed:
            state.showDeleteConfirmation = false
            statusStreamTask?.cancel()
            statusStreamTask = nil
            if let sourceID = state.processingSourceID {
                uploadTask?.cancel()
                uploadTask = Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await self.uploadUseCase.deleteSource(id: sourceID)
                        self.resetState()
                        self.state.shouldDismiss = true
                    } catch {
                        self.state.deletionError = error.localizedDescription
                    }
                }
            } else {
                stopProcessing()
                resetState()
                state.shouldDismiss = true
            }
        case .dismissDeleteConfirmation: state.showDeleteConfirmation = false
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
            guard count >= Self.manualContentMin else { state.manualContentError = String(localized: "Content must be at least 10 characters long."); return false }
            guard count <= Self.manualContentMax else { state.manualContentError = String(localized: "Content exceeds maximum limit of 100,000 characters."); return false }
            return true
        }
    }

    private func performUpload() async {
        defer { state.isSubmitting = false }
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
            stopFileAccess()
        } catch {
            stopFileAccess()
            state.submitError = error.localizedDescription
            return
        }

        state.processingSourceID = source.id
        state.processingSourceTitle = source.title
        state.processingSource = source

        beginProcessing(for: source)
    }

    private func beginProcessing(for source: Source) {
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
            startSSEProgress()
        }
    }

    private func startSSEProgress() {
        guard let sourceID = state.processingSourceID else { return }
        Logger.debug("Starting SSE stream for source: \(sourceID)")

        let stream = uploadUseCase.sourceStatusStream()

        statusStreamTask = Task { [weak self] in
            guard let self else { return }
            var receivedTerminalEvent = false
            do {
                for try await event in stream {
                    guard !Task.isCancelled else { return }

                    if event.sourceId == sourceID {
                        if event.state == "ready" || event.state == "failed" {
                            receivedTerminalEvent = true
                        }
                        self.applyStatusEvent(event)
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    Logger.debug("SSE stream ended: \(error)")
                }
            }
            if !receivedTerminalEvent, !Task.isCancelled {
                self.finishProcessing(success: false)
            }
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

    private func stopProcessing() {
        uploadTask?.cancel(); uploadTask = nil
        statusStreamTask?.cancel(); statusStreamTask = nil
    }
    private func resetState() { stopFileAccess(); state = State() }

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

    private func stopFileAccess() {
        pageCountTask?.cancel()
        pageCountTask = nil
        guard isFileAccessing else { return }
        isFileAccessing = false
        state.selectedFileURL?.stopAccessingSecurityScopedResource()
    }
}

extension Int64 {
    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
