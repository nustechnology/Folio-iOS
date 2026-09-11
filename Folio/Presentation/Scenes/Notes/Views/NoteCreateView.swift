import SwiftUI

struct NoteCreateView: View {
    @ObservedObject var viewModel: NoteListViewModel
    @StateObject private var editingModel: NoteRichTextEditingModel

    init(viewModel: NoteListViewModel) {
        self.viewModel = viewModel
        _editingModel = StateObject(
            wrappedValue: NoteRichTextEditingModel(
                attributedText: FolioRichTextEditor.makeDefaultAttributedText(),
                publishingHTML: { [viewModel] html in
                    viewModel.handle(.createContentChanged(html))
                }
            )
        )
    }

    var body: some View {
        NoteCreateForm(
            editingModel: editingModel,
            title: titleBinding,
            titleError: viewModel.state.createTitleError,
            contentError: viewModel.state.createContentError,
            errorMessage: nil,
            isSaving: viewModel.state.isCreating,
            hasUnsavedChanges: viewModel.hasCreateDraft,
            heading: String(localized: "New note"),
            explanation: String(localized: "Capture ideas, quotes and observations for this space."),
            onContentEditingEnded: { viewModel.handle(.createContentEditingEnded) },
            onSave: { _ in viewModel.handle(.createSaveTapped) },
            onCancel: { viewModel.handle(.createCancelTapped) },
            onDiscardConfirmed: { viewModel.handle(.createDiscardConfirmed) }
        )
        .onAppear {
            editingModel.attributedText = FolioRichTextEditor.attributedTextFromHTML(viewModel.state.createContent)
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { viewModel.state.createTitle },
            set: { viewModel.handle(.createTitleChanged($0)) }
        )
    }
}
