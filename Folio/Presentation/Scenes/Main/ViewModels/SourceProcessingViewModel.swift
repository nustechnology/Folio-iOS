import Foundation
import Combine

@MainActor
final class SourceProcessingViewModel: ObservableObject {
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

    struct State {
        var source: Source
        var isProcessing = false
        var isProcessingComplete = false
        var isProcessingFailed = false
        var processingProgress: Double = 0
        var processingStages: [(stage: ProcessingStage, status: StageStatus)] = []
        var processingStageLabel = ""
        var errorMessage: String?
        var isRetrying = false
        var isDeleting = false
        var showDeleteConfirmation = false
        var shouldDismiss = false
    }

    @Published private(set) var state: State

    private let onBack: () -> Void
    private let onDeleted: (Source) -> Void
    private let onStatusChanged: (Source) -> Void

    private let uploadSourceUseCase: any UploadSourceUseCaseProtocol
    private nonisolated(unsafe) var statusStreamTask: Task<Void, Never>?
    private let sourceID: String

    init(
        source: Source,
        uploadSourceUseCase: any UploadSourceUseCaseProtocol,
        onBack: @escaping () -> Void,
        onDeleted: @escaping (Source) -> Void,
        onStatusChanged: @escaping (Source) -> Void
    ) {
        self.state = State(source: source)
        self.uploadSourceUseCase = uploadSourceUseCase
        self.sourceID = source.id
        self.onBack = onBack
        self.onDeleted = onDeleted
        self.onStatusChanged = onStatusChanged
        if source.processingState == .failed {
            showFailureState(for: source)
        } else {
            beginProcessing(for: source)
        }
    }

    deinit {
        statusStreamTask?.cancel()
    }

    enum Intent {
        case back
        case retry
        case deleteTapped
        case deleteConfirmed
        case cancelDelete
    }

    func send(_ intent: Intent) {
        switch intent {
        case .back:
            stopStream()
            onBack()
        case .retry:
            guard !state.isRetrying else { return }
            state.isRetrying = true
            state.errorMessage = nil
            Task { await performRetry() }
        case .deleteTapped:
            state.showDeleteConfirmation = true
        case .deleteConfirmed:
            guard !state.isDeleting else { return }
            state.showDeleteConfirmation = false
            state.isDeleting = true
            Task { await performDelete() }
        case .cancelDelete:
            state.showDeleteConfirmation = false
        }
    }

    // MARK: - Processing

    private func beginProcessing(for source: Source) {
        state.isProcessing = true
        state.isProcessingComplete = false
        state.isProcessingFailed = false
        state.processingProgress = 0
        state.processingStages = ProcessingStage.allCases.map { ($0, .pending) }
        let currentIndex = stageIndex(for: source.processingState)
        seedStages(from: source.processingState)
        state.processingProgress = seedProgress(for: currentIndex)

        switch source.processingState {
        case .ready:
            finishProcessing(success: true)
        case .failed:
            finishProcessing(success: false)
        default:
            startSSEProgress()
        }
    }

    private func seedStages(from processingState: SourceProcessingState) {
        let currentIndex = stageIndex(for: processingState)
        for index in 0..<state.processingStages.count {
            if index < currentIndex {
                updateStage(index, status: .completed)
            } else if index == currentIndex {
                updateStage(index, status: .active)
            }
        }
    }

    private func seedProgress(for stageIndex: Int) -> Double {
        switch stageIndex {
        case 0: return 0
        case 1: return 0.4
        case 2: return 0.7
        case 3: return 1
        default: return 0
        }
    }

    private func stageIndex(for processingState: SourceProcessingState) -> Int {
        switch processingState {
        case .added: return 0
        case .extractingText: return 1
        case .indexingEvidence: return 2
        case .ready, .failed: return 3
        }
    }

    private func showFailureState(for source: Source) {
        state.isProcessing = false
        state.isProcessingComplete = false
        state.isProcessingFailed = true
        state.processingProgress = 0
        state.processingStages = ProcessingStage.allCases.map { ($0, .failed) }
        state.processingStageLabel = String(localized: "Failed")
        state.errorMessage = source.processingError.isEmpty
            ? String(localized: "Processing failed: Could not extract information from the document.")
            : source.processingError
    }

    private func startSSEProgress(retryCount: Int = 0) {
        Logger.debug("SourceProcessing: starting SSE stream for source: \(sourceID), attempt: \(retryCount + 1)")
        if retryCount == 0 {
            statusStreamTask?.cancel()
        }
        let stream = uploadSourceUseCase.sourceStatusStream()

        statusStreamTask = Task { [weak self] in
            guard let self else { return }
            var receivedTerminalEvent = false
            do {
                for try await event in stream {
                    guard !Task.isCancelled else { return }
                    if event.sourceId == self.sourceID {
                        if event.state == "ready" || event.state == "failed" {
                            receivedTerminalEvent = true
                        }
                        self.applyStatusEvent(event)
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    Logger.debug("SourceProcessing: SSE stream ended: \(error)")
                }
            }
            if !receivedTerminalEvent, !Task.isCancelled {
                let maxRetries = 3
                if retryCount < maxRetries {
                    let delay = UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000
                    Logger.debug("SourceProcessing: SSE stream closed without terminal event, retrying in \(delay / 1_000_000_000)s")
                    try? await Task.sleep(nanoseconds: delay)
                    guard !Task.isCancelled else { return }
                    self.startSSEProgress(retryCount: retryCount + 1)
                } else {
                    Logger.debug("SourceProcessing: SSE stream exhausted \(maxRetries) reconnects, waiting for user retry")
                    state.isProcessing = false
                    state.errorMessage = String(localized: "Lost connection to the server. Tap retry to reconnect.")
                }
            }
        }
    }

    private func applyStatusEvent(_ event: SourceStatusEvent) {
        let stageIndex = stageIndexForState(event.state)
        let progress = Double(event.progress) / 100.0

        state.processingProgress = progress

        for index in 0..<ProcessingStage.allCases.count {
            if index < stageIndex { updateStage(index, status: .completed) }
            else if index == stageIndex {
                if event.state == "failed" {
                    updateStage(index, status: .failed)
                } else {
                    updateStage(index, status: .active)
                }
            }
        }

        if event.state == "ready" {
            state.source = state.source.withProcessingState(.ready)
            finishProcessing(success: true)
        } else if event.state == "failed" {
            state.source = state.source.withProcessingState(.failed)
            state.errorMessage = state.source.processingError.isEmpty
                ? String(localized: "Processing failed: Could not extract information from the document.")
                : state.source.processingError
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
            for index in 0..<ProcessingStage.allCases.count { updateStage(index, status: .completed) }
        } else {
            state.isProcessingFailed = true
            state.isProcessingComplete = false
            state.processingStageLabel = String(localized: "Failed")
            state.processingProgress = 0
            if state.errorMessage == nil || state.errorMessage?.isEmpty == true {
                state.errorMessage = state.source.processingError.isEmpty
                    ? String(localized: "Processing failed: Could not extract information from the document.")
                    : state.source.processingError
            }
            for index in 0..<ProcessingStage.allCases.count { updateStage(index, status: .failed) }
        }
        onStatusChanged(state.source)
    }

    private func updateStage(_ index: Int, status: StageStatus) {
        guard index < state.processingStages.count else { return }
        var stages = state.processingStages
        stages[index].status = status
        state.processingStages = stages
        if status == .active || status == .completed { state.processingStageLabel = stages[index].stage.title }
    }

    // MARK: - Retry / Delete

    private func performRetry() async {
        defer { state.isRetrying = false }
        do {
            let source = try await uploadSourceUseCase.retrySource(id: sourceID)
            state.source = source
            state.isProcessingFailed = false
            state.isProcessingComplete = false
            state.processingProgress = 0
            state.processingStageLabel = ""
            state.errorMessage = nil
            beginProcessing(for: source)
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func performDelete() async {
        defer { state.isDeleting = false }
        stopStream()
        do {
            try await uploadSourceUseCase.deleteSource(id: sourceID)
            onDeleted(state.source)
            state.shouldDismiss = true
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func stopStream() {
        statusStreamTask?.cancel()
        statusStreamTask = nil
    }
}
