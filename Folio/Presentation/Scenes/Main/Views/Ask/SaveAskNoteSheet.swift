import SwiftUI

struct SaveAskNoteSheet: View {
    let draft: SaveAskNoteDraft
    let isSaving: Bool
    let errorMessage: String?
    let onTitleChanged: (String) -> Void
    let onContentChanged: (String) -> Void
    let onCancel: () -> Void
    let onSubmit: (String) -> Void

    @StateObject private var editingModel: NoteRichTextEditingModel

    init(
        draft: SaveAskNoteDraft,
        isSaving: Bool,
        errorMessage: String?,
        onTitleChanged: @escaping (String) -> Void,
        onContentChanged: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (String) -> Void
    ) {
        self.draft = draft
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onTitleChanged = onTitleChanged
        self.onContentChanged = onContentChanged
        self.onCancel = onCancel
        self.onSubmit = onSubmit
        _editingModel = StateObject(
            wrappedValue: NoteRichTextEditingModel(
                attributedText: FolioRichTextEditor.attributedTextFromHTML(draft.content),
                publishingHTML: onContentChanged
            )
        )
    }

    var body: some View {
        NoteCreateForm(
            editingModel: editingModel,
            title: titleBinding,
            titleError: titleError,
            contentError: contentError,
            errorMessage: errorMessage,
            isSaving: isSaving,
            hasUnsavedChanges: draft.hasUnsavedChanges,
            heading: String(localized: "Save as note"),
            explanation: String(localized: "Review the answer and adjust the title before saving it to this space."),
            onContentEditingEnded: {},
            onSave: onSubmit,
            onCancel: onCancel,
            onDiscardConfirmed: onCancel
        )
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { draft.title },
            set: onTitleChanged
        )
    }

    private var titleError: String? {
        validation.titleError?.localizedMessage
    }

    private var contentError: String? {
        validation.contentError?.localizedMessage
    }

    private var validation: NoteValidationResult {
        NoteLimits.validate(
            title: draft.title,
            serializedContent: editingModel.serializedContent,
            plainText: editingModel.plainText
        )
    }
}
