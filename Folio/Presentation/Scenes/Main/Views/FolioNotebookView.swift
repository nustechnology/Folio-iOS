import SwiftUI

struct FolioNotebookView: View {
    @ObservedObject var viewModel: NotebookViewModel
    let noteListViewModel: NoteListViewModel?
    let workspaceTitle: String
    let onBackToSpaces: () -> Void
    let onNavigateToNotes: () -> Void
    let onSourceOpened: (String) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var pendingExportAction: PendingExportAction?
    @State private var pendingQuickNotesAction: PendingQuickNotesAction?
    @State private var pendingNote: NoteSummary?
    @State private var pendingSourceID: String?
    @State private var shareURL: ShareableURL?
    @State private var isPrintPresented = false

    private enum PendingExportAction {
        case copy
        case markdown
        case print
    }

    private enum PendingQuickNotesAction {
        case newNote
        case manageNotes
    }

    private enum ActiveSheet: Identifiable {
        case export
        case quickNotes
        case share(ShareableURL)
        case print
        case noteDetail(Note)
        case newNote

        var id: String {
            switch self {
            case .export: return "export"
            case .quickNotes: return "quickNotes"
            case .share: return "share"
            case .print: return "print"
            case .noteDetail: return "noteDetail"
            case .newNote: return "newNote"
            }
        }
    }

    private struct ShareableURL: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if viewModel.state.isLoading {
                notebookSkeleton
            } else {
                RichTextToolbar(
                    onBold: { viewModel.handle(.bold) },
                    onItalic: { viewModel.handle(.italic) },
                    onHeading1: { viewModel.handle(.heading1) },
                    onHeading2: { viewModel.handle(.heading2) },
                    onHeading3: { viewModel.handle(.heading3) },
                    onUnorderedList: { viewModel.handle(.unorderedList) },
                    onOrderedList: { viewModel.handle(.orderedList) },
                    onBlockquote: { viewModel.handle(.blockquote) },
                    onUndo: { viewModel.handle(.undo) },
                    onRedo: { viewModel.handle(.redo) },
                    canUndo: viewModel.canUndo,
                    canRedo: viewModel.canRedo,
                    saveStatus: viewModel.state.saveStatus
                )
                .onTapGesture { dismissKeyboard() }

                editorArea
            }
        }
        .background(Color.folioCanvas)
        .task {
            viewModel.handle(.onAppear)
        }
        .onDisappear {
            viewModel.flushPendingSave()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                viewModel.flushPendingSave()
            }
        }
        .sheet(item: activeSheetBinding, onDismiss: {
            runPendingExport()
            runPendingQuickNotes()
            openPendingSource()
        }, content: { sheet in
            switch sheet {
            case .export:
                FolioExportSheet(
                    onCopy: { requestExport(.copy) },
                    onExportMarkdown: { requestExport(.markdown) },
                    onPrint: { requestExport(.print) },
                    onDismiss: { viewModel.handle(.toggleExportSheet) }
                )
            case .quickNotes:
                if let noteListViewModel {
                    QuickNotesPanel(
                        noteListViewModel: noteListViewModel,
                        spaceName: workspaceTitle,
                        onNoteTap: { note in
                            pendingNote = note
                            viewModel.dismissQuickNotes()
                        },
                        onNewNote: {
                            pendingQuickNotesAction = .newNote
                            viewModel.dismissQuickNotes()
                        },
                        onManageNotes: {
                            pendingQuickNotesAction = .manageNotes
                            viewModel.dismissQuickNotes()
                        },
                        onDismiss: { viewModel.handle(.toggleQuickNotes) }
                    )
                }
            case .share(let shareable):
                FolioShareSheet(items: [shareable.url])
            case .print:
                FolioPrintSheet(
                    attributedText: viewModel.printableContent,
                    onCompletion: { isPrintPresented = false }
                )
            case .noteDetail(let note):
                NoteDetailView(
                    note: note,
                    onEdit: {
                        noteListViewModel?.handle(.dismissSheet)
                        onNavigateToNotes()
                    },
                    onConvert: {
                        noteListViewModel?.handle(.dismissSheet)
                        onNavigateToNotes()
                    },
                    onOpenSource: { sourceID in
                        pendingSourceID = sourceID
                        noteListViewModel?.handle(.dismissSheet)
                    },
                    showsActions: false
                )
            case .newNote:
                if let noteListViewModel {
                    NoteCreateView(viewModel: noteListViewModel)
                }
            }
        })
        .onChange(of: noteListViewModel?.state.sheet) { _, sheet in
            if sheet == nil {
                viewModel.handle(.closeNewNote)
            }
        }
        .onChange(of: viewModel.state.showQuickNotesSheet) { _, isPresented in
            if isPresented {
                noteListViewModel?.handle(.refresh)
            }
        }
        .folioToast(message: $viewModel.toastMessage)
    }

    private var detailNote: Note? {
        if case .detail(let note)? = noteListViewModel?.state.sheet { return note }
        return nil
    }

    private var activeSheet: ActiveSheet? {
        if viewModel.state.showExportSheet { return .export }
        if viewModel.state.showQuickNotesSheet { return .quickNotes }
        if let url = shareURL { return .share(url) }
        if isPrintPresented { return .print }
        if let note = detailNote { return .noteDetail(note) }
        if viewModel.state.showNewNoteSheet { return .newNote }
        return nil
    }

    private var activeSheetBinding: Binding<ActiveSheet?> {
        Binding(
            get: { activeSheet },
            set: { newValue in
                if newValue == nil { dismissActiveSheet() }
            }
        )
    }

    private func dismissActiveSheet() {
        switch activeSheet {
        case .export:
            if viewModel.state.showExportSheet { viewModel.handle(.toggleExportSheet) }
        case .quickNotes:
            if viewModel.state.showQuickNotesSheet { viewModel.handle(.toggleQuickNotes) }
        case .share:
            shareURL = nil
        case .print:
            isPrintPresented = false
        case .noteDetail:
            noteListViewModel?.handle(.dismissSheet)
        case .newNote:
            if viewModel.state.showNewNoteSheet { viewModel.handle(.setNewNotePresented(false)) }
            noteListViewModel?.handle(.createDismissalAttempted)
        case .none:
            break
        }
    }

    private func openPendingSource() {
        guard let sourceID = pendingSourceID else { return }
        pendingSourceID = nil
        onSourceOpened(sourceID)
    }

    private var topBar: some View {
        FolioTopBar(
            title: String(localized: "Notebook"),
            subtitle: workspaceTitle,
            leading: AnyView(
                Button(action: onBackToSpaces) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: FolioFontSize.bodySmall, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: FolioSize.iconLg, height: FolioSize.iconLg)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Back to My Spaces"))
            ),
            trailing: [
                AnyView(
                    Button(action: { viewModel.handle(.toggleExportSheet) }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: FolioFontSize.body, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: FolioSize.buttonMd, height: FolioSize.buttonMd)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Notebook actions"))
                )
            ]
        )
        .padding(.top, FolioSpacing.xs)
        .background(Color.folioOlive)
        .onTapGesture { dismissKeyboard() }
    }

    private var editorArea: some View {
        ZStack(alignment: .bottom) {
            FolioRichTextEditor(
                attributedText: $viewModel.attributedText,
                selectedRange: $viewModel.selectedRange,
                onTextChange: { viewModel.handle(.textChanged($0)) },
                canUndo: viewModel.canUndo,
                canRedo: viewModel.canRedo,
                onBlockquoteShortcut: { viewModel.handle(.blockquote) },
                onUnorderedListShortcut: { viewModel.handle(.unorderedList) },
                onOrderedListShortcut: { viewModel.handle(.orderedList) },
                onUndoShortcut: { viewModel.handle(.undo) },
                onRedoShortcut: { viewModel.handle(.redo) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.folioCanvas)

            if viewModel.attributedText.string.isEmpty {
                emptyPlaceholder
            }

            quickNotesButton
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "book")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Color.folioInkSoft)

            Text(String(localized: "Start typing your notes, research, or report here..."))
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(Color.folioInkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var quickNotesButton: some View {
        VStack {
            Spacer()

            Button(action: { viewModel.handle(.toggleQuickNotes) }) {
                HStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 14, weight: .medium))

                    Text(String(localized: "View notes"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.folioGold)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.folioOliveDark)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.folioGold.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
    }

    private var notebookSkeleton: some View {
        VStack(spacing: 0) {
            RichTextToolbar(
                onBold: {}, onItalic: {}, onHeading1: {}, onHeading2: {}, onHeading3: {},
                onUnorderedList: {}, onOrderedList: {}, onBlockquote: {},
                onUndo: {}, onRedo: {},
                canUndo: false, canRedo: false,
                saveStatus: .saved
            )

            VStack(spacing: 16) {
                ForEach(0..<8, id: \.self) { index in
                    skeletonRow(index: index)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.folioCanvas)

            Spacer()
        }
    }

    private func skeletonRow(index: Int) -> some View {
        let widths: [CGFloat] = [0.4, 0.9, 0.7, 0.85, 0.5, 0.9, 0.6, 0.75]
        let width = widths[index % widths.count]

        return GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.folioLine.opacity(0.5))
                .frame(width: geometry.size.width * width, height: FolioSize.skeletonBarHeight)
        }
        .frame(height: FolioSize.skeletonBarHeight)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func requestExport(_ action: PendingExportAction) {
        pendingExportAction = action
        viewModel.handle(.toggleExportSheet)
    }

    private func runPendingExport() {
        let action = pendingExportAction
        pendingExportAction = nil
        switch action {
        case .copy:
            viewModel.copyToClipboard()
        case .markdown:
            if let url = viewModel.markdownExportURL() {
                shareURL = ShareableURL(url: url)
            } else {
                viewModel.toastMessage = .error(String(localized: "Failed to export notebook"))
            }
        case .print:
            isPrintPresented = true
        case .none:
            break
        }
    }

    private func runPendingQuickNotes() {
        defer {
            pendingNote = nil
            pendingQuickNotesAction = nil
        }
        if let note = pendingNote {
            noteListViewModel?.handle(.noteSelected(note))
            return
        }
        switch pendingQuickNotesAction {
        case .newNote:
            noteListViewModel?.handle(.newTapped)
            viewModel.handle(.toggleNewNote)
        case .manageNotes:
            onNavigateToNotes()
        case .none:
            break
        }
    }
}

private struct QuickNotesPanel: View {
    @ObservedObject var noteListViewModel: NoteListViewModel
    let spaceName: String
    let onNoteTap: (NoteSummary) -> Void
    let onNewNote: () -> Void
    let onManageNotes: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        FolioQuickNotesSheet(
            spaceName: spaceName,
            notes: noteListViewModel.state.notes,
            isLoading: noteListViewModel.state.isLoading,
            onNoteTap: onNoteTap,
            onNewNote: onNewNote,
            onManageNotes: onManageNotes,
            onDismiss: onDismiss
        )
    }
}

private struct FolioPrintSheet: UIViewControllerRepresentable {
    let attributedText: NSAttributedString
    let onCompletion: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        guard !context.coordinator.printed else { return }
        context.coordinator.printed = true

        let printFormatter = UISimpleTextPrintFormatter(attributedText: attributedText)
        printFormatter.perPageContentInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)

        let printController = UIPrintInteractionController.shared
        printController.printFormatter = printFormatter

        let sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
        let didPresent = printController.present(from: sourceRect, in: controller.view, animated: true) { _, _, error in
            if let error {
                Logger.error("Print failed: \(error)")
            }
            onCompletion()
        }
        if !didPresent {
            Logger.error("Print presentation was not started")
            onCompletion()
        }
    }

    final class Coordinator {
        var printed = false
    }
}

#Preview {
    FolioNotebookView(
        viewModel: NotebookViewModel(
            fetchNotebookUseCase: PreviewFetchNotebookUseCase(),
            saveNotebookUseCase: PreviewSaveNotebookUseCase()
        ),
        noteListViewModel: nil,
        workspaceTitle: "Dissertation Research",
        onBackToSpaces: {},
        onNavigateToNotes: {},
        onSourceOpened: { _ in }
    )
}

private final class PreviewFetchNotebookUseCase: FetchNotebookUseCaseProtocol {
    func execute(spaceId: String) async throws -> NotebookFetchResult {
        NotebookFetchResult(
            entry: NotebookEntry(id: "", researchSpaceId: spaceId, content: "", createdAt: Date(), updatedAt: Date()),
            preservedOfflineDraft: false)
    }
}

private final class PreviewSaveNotebookUseCase: SaveNotebookUseCaseProtocol {
    func execute(entry: NotebookEntry) async throws {}
}
