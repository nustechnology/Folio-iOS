import SwiftUI

struct SaveAskNoteSheet: View {
    let draft: SaveAskNoteDraft
    let isSaving: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSubmit: (String, String) -> Void

    @State private var title: String
    @StateObject private var editingModel: NoteRichTextEditingModel

    static func contentToSave(
        draftContent: String,
        editingModel: NoteRichTextEditingModel
    ) -> String {
        editingModel.contentForSave(fallback: draftContent)
    }

    init(
        draft: SaveAskNoteDraft,
        isSaving: Bool,
        errorMessage: String?,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (String, String) -> Void
    ) {
        self.draft = draft
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onCancel = onCancel
        self.onSubmit = onSubmit
        _title = State(initialValue: draft.title)
        _editingModel = StateObject(
            wrappedValue: NoteRichTextEditingModel(
                attributedText: FolioRichTextEditor.attributedTextFromHTML(draft.content),
                publishingHTML: { _ in }
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
            onSave: { _ in onSubmit(title, contentForSave) },
            onCancel: onCancel,
            onDiscardConfirmed: onCancel,
            contentPresentation: .readOnly,
            displayContent: draft.initialContent,
            contentBackgroundColor: .folioHomeReadOnlyFieldBackground,
            usesDynamicSheetHeight: true
        )
    }

    private var titleBinding: Binding<String> {
        $title
    }

    private var hasUnsavedChanges: Bool {
        title != draft.initialTitle || editingModel.hasUnsavedChanges
    }

    private var contentForSave: String {
        Self.contentToSave(draftContent: draft.initialContent, editingModel: editingModel)
    }

    private var validation: NoteValidationResult {
        let content = contentForSave
        return NoteLimits.validate(
            title: title,
            serializedContent: content,
            plainText: NoteLimits.plainText(from: content)
        )
    }
}
