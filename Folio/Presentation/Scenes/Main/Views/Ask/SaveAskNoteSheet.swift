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
            validation: validation,
            errorMessage: errorMessage,
            isSaving: isSaving,
            hasUnsavedChanges: hasUnsavedChanges,
            heading: String(localized: "Save as note"),
            explanation: String(localized: "Review the answer and adjust the title before saving it to this space."),
            onContentEditingEnded: {},
            onSave: { _ in onSubmit(contentForSave) },
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

    private var hasUnsavedChanges: Bool {
        draft.title != draft.initialTitle || editingModel.hasUnsavedChanges
    }

    private var contentForSave: String {
        editingModel.contentForSave(fallback: draft.initialContent)
    }

    private var validation: NoteValidationResult {
        let content = contentForSave
        return NoteLimits.validate(
            title: draft.title,
            serializedContent: content,
            plainText: NoteLimits.plainText(from: content)
        )
    }
}
