import SwiftUI

struct NoteCreateForm: View {
    @ObservedObject var editingModel: NoteRichTextEditingModel
    @Binding var title: String

    let validation: NoteValidationResult
    let errorMessage: String?
    let isSaving: Bool
    let hasUnsavedChanges: Bool
    let heading: String
    let explanation: String
    let onContentEditingEnded: () -> Void
    let onSave: (String) -> Void
    let onCancel: () -> Void
    let onDiscardConfirmed: () -> Void

    @State private var toast: ToastMessage?
    @State private var isDiscardConfirmationPresented = false

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: FolioRadius.handle)
                .fill(Color.folioHomeSheetHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioRadius.handle * 2)
                .padding(.top, FolioSpacing.sm)
                .padding(.bottom, FolioSpacing.xl2)

            VStack(alignment: .leading, spacing: FolioSpacing.sm) {
                Text(heading)
                    .font(.custom("CormorantGaramond-Medium", size: FolioFontSize.heading))
                    .foregroundStyle(Color.folioInk)

                Text(explanation)
                    .font(.system(size: FolioFontSize.bodySmall))
                    .foregroundStyle(Color.folioInkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.bottom, FolioSpacing.xl3)

            ScrollView {
                VStack(alignment: .leading, spacing: FolioSpacing.lg) {
                    FolioTextField(
                        label: String(localized: "Title"),
                        placeholder: String(localized: "Untitled Note"),
                        text: $title,
                        style: .singleLine,
                        error: validation.titleError?.localizedMessage
                    )
                    .disabled(isSaving)

                    HStack {
                        Spacer()
                        Text("\(title.count) / \(NoteLimits.maximumTitleLength)")
                            .font(.system(size: FolioFontSize.caption2))
                            .foregroundStyle(Color.folioInkSoft)
                    }

                    Text(String(localized: "Content"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.folioHomeTypeTextText)

                    if let linkError = editingModel.linkError {
                        Text(linkError)
                            .font(.system(size: FolioFontSize.caption2))
                            .foregroundStyle(Color.folioDanger)
                    }

                    if let contentError = validation.contentError?.localizedMessage {
                        Text(contentError)
                            .font(.system(size: FolioFontSize.caption2))
                            .foregroundStyle(Color.folioDanger)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: FolioFontSize.caption2))
                            .foregroundStyle(Color.folioDanger)
                    }

                    ZStack(alignment: .top) {
                        FolioRichTextEditor(
                            attributedText: $editingModel.attributedText,
                            selectedRange: $editingModel.selectedRange,
                            typingAttributes: $editingModel.typingAttributes,
                            onTextChange: editingModel.textChanged,
                            onEditingChanged: { isEditing in
                                if !isEditing { onContentEditingEnded() }
                            },
                            textContainerTopInset: 48
                        )

                        if editingModel.attributedText.string.isEmpty {
                            Text(String(localized: "What stood out, and why does it matter for this research?"))
                                .font(.system(size: 14))
                                .foregroundStyle(Color.folioInkSoft.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(.top, 48)
                                .padding(.horizontal, 16)
                                .allowsHitTesting(false)
                        }

                        RichTextToolbar(
                            onBold: { editingModel.applyTrait(.traitBold) },
                            onItalic: { editingModel.applyTrait(.traitItalic) },
                            onHeading1: { editingModel.applyHeading(FolioRichTextFormat.heading1FontSize) },
                            onHeading2: { editingModel.applyHeading(FolioRichTextFormat.heading2FontSize) },
                            onHeading3: { editingModel.applyHeading(FolioRichTextFormat.heading3FontSize) },
                            onUnorderedList: { editingModel.applyList(ordered: false) },
                            onOrderedList: { editingModel.applyList(ordered: true) },
                            onBlockquote: editingModel.applyBlockquote,
                            onHyperlink: presentLinkPrompt,
                            onUndo: {},
                            onRedo: {},
                            canUndo: false,
                            canRedo: false,
                            saveStatus: .saved,
                            configuration: .notes,
                            activeFormats: editingModel.toolbarActiveFormats,
                            isEmbedded: true
                        )
                    }
                    .frame(minHeight: Constants.contentMinHeight, maxHeight: Constants.contentMaxHeight)
                    .background(Color.folioSurfaceStrong)
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous)
                            .stroke(
                                contentError == nil ? Color.folioFieldBorder : Color.folioDanger,
                                lineWidth: 1
                            )
                    )
                    .disabled(isSaving)

                    HStack {
                        Spacer()
                        Text("\(plainText.count) / \(NoteLimits.maximumContentLengthLabel)")
                            .font(.system(size: FolioFontSize.caption2))
                            .foregroundStyle(
                                plainText.count > NoteLimits.maximumContentLength
                                    ? Color.folioDanger
                                    : Color.folioInkSoft
                            )
                    }

                    actionButtons
                }
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl)
            }
        }
        .background(Color.folioHomeSheetBackground)
        .dismissKeyboardOnTapOutside()
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(FolioRadius.xl2)
        .folioDynamicSheet(minHeight: FolioSize.noteCreateSheetMinH, maxHeight: FolioSize.noteCreateSheetMaxH)
        .presentationDragIndicator(.hidden)
        .interceptInteractiveDismiss(
            isBlocked: isSaving || hasUnsavedChanges,
            onAttemptToDismiss: requestDismissal
        )
        .folioToast(message: $toast)
        .fullScreenCover(isPresented: $editingModel.isLinkPromptPresented) {
            FolioLinkPrompt(
                url: $editingModel.linkURL,
                error: editingModel.linkError,
                onCancel: { editingModel.isLinkPromptPresented = false },
                onAdd: { _ = editingModel.applyLink() }
            )
            .presentationBackground(.clear)
            .interactiveDismissDisabled(true)
        }
        .fullScreenCover(isPresented: $isDiscardConfirmationPresented) {
            NoteDiscardConfirmationView(
                title: String(localized: "Discard unsaved note?"),
                message: String(localized: "Your unsaved note will be lost."),
                onCancel: { isDiscardConfirmationPresented = false },
                onDiscard: {
                    isDiscardConfirmationPresented = false
                    onDiscardConfirmed()
                }
            )
            .presentationBackground(.clear)
            .interactiveDismissDisabled(true)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: FolioSpacing.lg) {
            FolioSecondaryButton(
                title: String(localized: "Cancel"),
                isDisabled: isSaving,
                action: requestDismissal
            )

            FolioPrimaryButton(
                title: String(localized: "Save note"),
                isLoading: isSaving,
                isEnabled: !isSaveDisabled,
                action: { onSave(serializedContent) }
            )
        }
        .padding(.top, FolioSpacing.sm)
    }

    private var isSaveDisabled: Bool {
        validation.titleError != nil
            || validation.contentError != nil
            || isSaving
    }

    private var serializedContent: String {
        editingModel.serializedContent
    }

    private var plainText: String {
        editingModel.plainText
    }

    private var contentError: String? {
        validation.contentError?.localizedMessage
    }

    private func requestDismissal() {
        guard !isSaving else { return }
        if hasUnsavedChanges {
            isDiscardConfirmationPresented = true
        } else {
            onCancel()
        }
    }

    private func presentLinkPrompt() {
        if !editingModel.presentLinkPrompt() {
            toast = .error(String(localized: "Select text to add a link"))
        }
    }

    private enum Constants {
        static let contentMinHeight: CGFloat = 160
        static let contentMaxHeight: CGFloat = 240
    }
}
