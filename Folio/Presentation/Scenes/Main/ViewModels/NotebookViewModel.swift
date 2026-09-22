import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class NotebookViewModel: ViewModelProtocol {
    struct State {
        var notebookEntry: NotebookEntry?
        var plainText: String = ""
        var saveStatus: RichTextToolbar.SaveStatus = .saved
        var showExportSheet: Bool = false
        var showNewNoteSheet: Bool = false
        var isLoading: Bool = true
        var loadFailed: Bool = false
    }

    @Published private(set) var state = State()
    @Published var toastMessage: ToastMessage?

    @Published var attributedText: NSAttributedString = NSAttributedString(string: "")
    @Published var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @Published var typingAttributes: [NSAttributedString.Key: Any] = [:]
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    private struct EditorSnapshot {
        let attributedText: NSAttributedString
        let selectedRange: NSRange
        let typingAttributes: [NSAttributedString.Key: Any]
    }

    private var undoStack: [EditorSnapshot] = []
    private var redoStack: [EditorSnapshot] = []
    private var isTypingSession = false
    private let maximumUndoSteps = 100
    var spaceId: String = ""
    var spaceName: String = ""

    var toolbarActiveFormats: RichTextToolbar.ActiveFormats {
        let formats = formattingController.activeFormats(
            in: attributedText,
            selectedRange: selectedRange,
            typingAttributes: typingAttributes
        )
        return RichTextToolbar.ActiveFormats(
            isBold: formats.isBold,
            isItalic: formats.isItalic,
            isHeading1: formats.isHeading1,
            isHeading2: formats.isHeading2,
            isHeading3: formats.isHeading3,
            isUnorderedList: formats.isUnorderedList,
            isOrderedList: formats.isOrderedList,
            hasLink: formats.hasLink,
            isBlockquote: formats.isBlockquote
        )
    }

    private let fetchNotebookUseCase: any FetchNotebookUseCaseProtocol
    private let saveNotebookUseCase: any SaveNotebookUseCaseProtocol
    private let formattingController = RichTextFormattingController()
    private var saveTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var typingSessionTask: Task<Void, Never>?
    private var isSaving = false
    private var pendingSaves: [QueuedSave] = []
    private let saveDebounceInterval: UInt64 = 1_500_000_000
    private let typingSessionIdleInterval: UInt64 = 1_000_000_000
    private let backgroundSaveTaskName = "NotebookSave"

    init(
        fetchNotebookUseCase: any FetchNotebookUseCaseProtocol,
        saveNotebookUseCase: any SaveNotebookUseCaseProtocol
    ) {
        self.fetchNotebookUseCase = fetchNotebookUseCase
        self.saveNotebookUseCase = saveNotebookUseCase
    }

    func configure(spaceId: String, spaceName: String) {
        self.spaceId = spaceId
        self.spaceName = spaceName
    }

    func handle(_ action: Action) {
        switch action {
        case .onAppear:
            loadNotebook()
        case .textChanged(let attributedText):
            handleTextChange(attributedText)
        case .bold:
            toggleTrait(.traitBold)
        case .italic:
            toggleTrait(.traitItalic)
        case .heading1:
            applyHeading(fontSize: FolioRichTextFormat.heading1FontSize)
        case .heading2:
            applyHeading(fontSize: FolioRichTextFormat.heading2FontSize)
        case .heading3:
            applyHeading(fontSize: FolioRichTextFormat.heading3FontSize)
        case .unorderedList:
            applyListStyle(ordered: false)
        case .orderedList:
            applyListStyle(ordered: true)
        case .blockquote:
            applyBlockquote()
        case .undo:
            undo()
        case .redo:
            redo()
        case .copyNotebook:
            copyToClipboard()
        case .toggleExportSheet:
            state.showExportSheet.toggle()
        case .toggleNewNote:
            state.showNewNoteSheet.toggle()
        case .setNewNotePresented(let isPresented):
            state.showNewNoteSheet = isPresented
        case .closeNewNote:
            state.showNewNoteSheet = false
        case .dismissToast:
            toastMessage = nil
        }
    }

    enum Action {
        case onAppear
        case textChanged(NSAttributedString)
        case bold
        case italic
        case heading1
        case heading2
        case heading3
        case unorderedList
        case orderedList
        case blockquote
        case undo
        case redo
        case copyNotebook
        case toggleExportSheet
        case toggleNewNote
        case setNewNotePresented(Bool)
        case closeNewNote
        case dismissToast
    }

    private func loadNotebook() {
        guard state.notebookEntry == nil else { return }
        state.isLoading = true
        state.loadFailed = false
        loadTask?.cancel()
        guard !spaceId.isEmpty else {
            state.isLoading = false
            return
        }
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await fetchNotebookUseCase.execute(spaceId: spaceId)
                let entry = result.entry
                guard !Task.isCancelled else { return }
                state.notebookEntry = entry
                if !entry.content.isEmpty {
                    attributedText = FolioRichTextEditor.attributedTextFromHTML(entry.content)
                    state.plainText = attributedText.string
                } else {
                    attributedText = NSAttributedString(string: "")
                    state.plainText = ""
                }
                selectedRange = NSRange(location: attributedText.length, length: 0)
                typingAttributes = [:]
                if result.preservedOfflineDraft {
                    toastMessage = .info(String(localized: "This notebook changed elsewhere — your offline draft was preserved"))
                }
            } catch {
                guard !Task.isCancelled else { return }
                state.loadFailed = true
                toastMessage = .error(String(localized: "Failed to load notebook"))
            }
            resetUndoStacks()
            state.isLoading = false
        }
    }

    private func handleTextChange(_ text: NSAttributedString) {
        guard !state.loadFailed else { return }

        if !isTypingSession {
            undoStack.append(currentSnapshot())
            trimUndoStack()
            redoStack.removeAll()
            isTypingSession = true
        }
        restartTypingSessionTimer()

        attributedText = text
        state.plainText = text.string
        state.saveStatus = .saving
        refreshUndoState()
        scheduleSave(text)
    }

    private func restartTypingSessionTimer() {
        typingSessionTask?.cancel()
        typingSessionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.typingSessionIdleInterval ?? 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.isTypingSession = false
        }
    }

    private struct QueuedSave {
        let entry: NotebookEntry
        let completions: [() -> Void]
    }

    private func enqueueSave(_ text: NSAttributedString, completion: (() -> Void)? = nil) {
        let html = FolioRichTextEditor.htmlFromAttributedText(text)
        let existing = state.notebookEntry
        let entry = NotebookEntry(
            id: existing?.id ?? "",
            researchSpaceId: spaceId,
            content: html,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
        let newCompletions = completion.map { [$0] } ?? []
        if let last = pendingSaves.last, last.entry.content == entry.content {
            pendingSaves[pendingSaves.count - 1] = QueuedSave(
                entry: entry,
                completions: last.completions + newCompletions
            )
        } else {
            pendingSaves.append(QueuedSave(entry: entry, completions: newCompletions))
        }
        drainSaveQueue()
    }

    private func drainSaveQueue() {
        guard !isSaving, let item = pendingSaves.first else { return }
        isSaving = true
        pendingSaves.removeFirst()
        state.saveStatus = .saving
        Task { [weak self] in
            guard let self else { return }
            if Task.isCancelled {
                item.completions.forEach { $0() }
                self.isSaving = false
                self.drainSaveQueue()
                return
            }
            do {
                try await self.saveNotebookUseCase.execute(entry: item.entry)
                self.state.notebookEntry = item.entry
                self.state.saveStatus = self.pendingSaves.isEmpty ? .saved : .saving
            } catch {
                Logger.error("Notebook save failed: \(error)")
                self.state.saveStatus = .failed
                self.toastMessage = .error(String(localized: "Failed to save notebook"))
            }
            item.completions.forEach { $0() }
            self.isSaving = false
            self.drainSaveQueue()
        }
    }

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let result = formattingController.toggleTrait(
            trait,
            in: attributedText,
            selectedRange: selectedRange,
            currentTypingAttributes: typingAttributes,
            appliesToTypingAttributes: true
        ) else { return }
        beginUndoableChange()
        applyFormatted(result)
    }

    private func applyHeading(fontSize: CGFloat) {
        guard let result = formattingController.applyHeading(
            fontSize: fontSize,
            in: attributedText,
            selectedRange: selectedRange,
            currentTypingAttributes: typingAttributes
        ) else { return }
        beginUndoableChange()
        applyFormatted(result)
    }

    private func applyListStyle(ordered: Bool) {
        guard let result = formattingController.applyListStyle(ordered: ordered, in: attributedText, selectedRange: selectedRange) else { return }
        beginUndoableChange()
        applyFormatted(result)
    }

    private func applyBlockquote() {
        guard let result = formattingController.applyBlockquote(in: attributedText, selectedRange: selectedRange) else { return }
        beginUndoableChange()
        applyFormatted(result)
    }

    private func applyFormatted(_ result: RichTextFormattingController.Result) {
        let previousAttributedText = attributedText
        attributedText = result.attributedText
        if let range = result.selectedRange {
            selectedRange = range
        }
        if let typingAttributes = result.typingAttributes {
            self.typingAttributes = typingAttributes
        }
        state.plainText = result.attributedText.string
        if result.attributedText != previousAttributedText {
            scheduleSave(result.attributedText)
        }
    }

    private func beginUndoableChange() {
        typingSessionTask?.cancel()
        undoStack.append(currentSnapshot())
        trimUndoStack()
        redoStack.removeAll()
        isTypingSession = false
        refreshUndoState()
    }

    private func undo() {
        typingSessionTask?.cancel()
        isTypingSession = false
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        applySnapshot(previous)
    }

    private func redo() {
        typingSessionTask?.cancel()
        isTypingSession = false
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        applySnapshot(next)
    }

    private func currentSnapshot() -> EditorSnapshot {
        EditorSnapshot(
            attributedText: attributedText,
            selectedRange: selectedRange,
            typingAttributes: typingAttributes
        )
    }

    private func applySnapshot(_ snapshot: EditorSnapshot) {
        let textChanged = snapshot.attributedText != attributedText
        attributedText = snapshot.attributedText
        selectedRange = snapshot.selectedRange
        typingAttributes = snapshot.typingAttributes
        state.plainText = snapshot.attributedText.string
        if textChanged {
            scheduleSave(snapshot.attributedText)
        }
        refreshUndoState()
    }

    private func resetUndoStacks() {
        typingSessionTask?.cancel()
        undoStack.removeAll()
        redoStack.removeAll()
        isTypingSession = false
        refreshUndoState()
    }

    private func trimUndoStack() {
        if undoStack.count > maximumUndoSteps {
            undoStack.removeFirst(undoStack.count - maximumUndoSteps)
        }
    }

    private func refreshUndoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func scheduleSave(_ text: NSAttributedString) {
        saveTask?.cancel()
        state.saveStatus = .saving
        saveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.saveDebounceInterval)
            guard !Task.isCancelled else { return }
            self.enqueueSave(text)
        }
    }

    func flushPendingSave() {
        saveTask?.cancel()
        guard state.saveStatus == .saving || !pendingSaves.isEmpty else { return }
        let backgroundTask = beginBackgroundSaveTask()
        enqueueSave(attributedText) { [weak self] in
            self?.endBackgroundSaveTask(backgroundTask)
        }
    }

    private func beginBackgroundSaveTask() -> UIBackgroundTaskIdentifier {
        var identifier: UIBackgroundTaskIdentifier = .invalid
        identifier = UIApplication.shared.beginBackgroundTask(withName: backgroundSaveTaskName) { [weak self] in
            self?.endBackgroundSaveTask(identifier)
            identifier = .invalid
        }
        return identifier
    }

    private func endBackgroundSaveTask(_ identifier: UIBackgroundTaskIdentifier) {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
    }

    func copyToClipboard() {
        UIPasteboard.general.string = NotebookExportService.plainText(from: attributedText)
        toastMessage = .success(String(localized: "Notebook copied to clipboard"))
    }

    func markdownExportURL() -> URL? {
        NotebookExportService.markdownExportURL(from: attributedText, spaceName: spaceName)
    }

    var printableContent: NSAttributedString {
        NotebookExportService.printableContent(from: attributedText)
    }
}

extension NotebookViewModel {
    func makeBinding<T>(_ keyPath: WritableKeyPath<State, T>, action: Action?) -> Binding<T> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { newValue in
                self.state[keyPath: keyPath] = newValue
                if let action { self.handle(action) }
            }
        )
    }
}
