import SwiftUI

enum NoteContentPresentation {
    case editable
    case readOnly
}

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
    var contentPresentation: NoteContentPresentation = .editable
    var displayContent: String? = nil
    var contentBackgroundColor: Color = .folioSurfaceStrong
    var usesDynamicSheetHeight = false
    var showsValidationErrors = true

    @State private var toast: ToastMessage?
    @State private var isDiscardConfirmationPresented = false
    @State private var headerHeight: CGFloat = 0
    @State private var sheetHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: FolioSpacing.lg) {
                    FolioTextField(
                        label: String(localized: "Title"),
                        placeholder: String(localized: "Untitled Note"),
                        text: $title,
                        style: .singleLine,
                        error: showsValidationErrors ? validation.titleError?.localizedMessage : nil
                    )
                    .disabled(isSaving)

                    HStack {
                        Spacer()
                        Text("\(title.count) / \(NoteLimits.maximumTitleLengthLabel)")
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

                    if showsValidationErrors, let contentError = validation.contentError?.localizedMessage {
                        Text(contentError)
                            .font(.system(size: FolioFontSize.caption2))
                            .foregroundStyle(Color.folioDanger)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: FolioFontSize.caption2))
                            .foregroundStyle(Color.folioDanger)
                    }

                    contentView
                    .frame(minHeight: Constants.contentMinHeight, maxHeight: Constants.contentMaxHeight)
                    .background(contentBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous)
                            .stroke(
                                contentBorderColor,
                                lineWidth: 1
                            )
                    )
                    .disabled(isSaving)

                    HStack {
                        Spacer()
                        Text("\(effectivePlainText.count) / \(NoteLimits.maximumContentLengthLabel)")
                            .font(.system(size: FolioFontSize.caption2))
                            .foregroundStyle(
                                effectivePlainText.count > NoteLimits.maximumContentLength
                                    ? Color.folioDanger
                                    : Color.folioInkSoft
                            )
                    }

                    actionButtons
                }
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl)
                .measureHeight($sheetHeight)
            }
        }
        .background(Color.folioHomeSheetBackground)
        .dismissKeyboardOnTapOutside()
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(FolioRadius.xl2)
        .noteCreateSheetDetents(
            isDynamic: usesDynamicSheetHeight,
            headerHeight: headerHeight,
            contentHeight: sheetHeight,
            minHeight: FolioSize.noteCreateSheetMinH,
            maxHeight: FolioSize.noteCreateSheetMaxH
        )
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

    private var header: some View {
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
        }
        .measureHeight($headerHeight)
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
                action: { onSave(effectiveSerializedContent) }
            )
        }
        .padding(.top, FolioSpacing.sm)
    }

    private var isSaveDisabled: Bool {
        validation.titleError != nil
            || validation.contentError != nil
            || isSaving
    }

    private var effectiveSerializedContent: String {
        switch contentPresentation {
        case .editable:
            return editingModel.serializedContent
        case .readOnly:
            return displayContent ?? editingModel.serializedContent
        }
    }

    private var effectivePlainText: String {
        switch contentPresentation {
        case .editable:
            return editingModel.plainText
        case .readOnly:
            return NoteLimits.plainText(from: effectiveSerializedContent)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch contentPresentation {
        case .editable:
            NoteRichTextEditorField(
                editingModel: editingModel,
                onContentEditingEnded: onContentEditingEnded,
                onLinkSelectionFailed: {
                    toast = .error(String(localized: "Select text to add a link"))
                }
            )
        case .readOnly:
            ScrollView {
                Text(AttributedString(FolioRichTextEditor.attributedTextFromHTML(effectiveSerializedContent)))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.folioInk)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var contentError: String? {
        showsValidationErrors ? validation.contentError?.localizedMessage : nil
    }

    private var contentBorderColor: Color {
        guard contentError == nil else { return Color.folioDanger }
        switch contentPresentation {
        case .editable:
            return Color.folioFieldBorder
        case .readOnly:
            return Color.folioLine.opacity(0.75)
        }
    }

    private func requestDismissal() {
        guard !isSaving else { return }
        if hasUnsavedChanges {
            isDiscardConfirmationPresented = true
        } else {
            onCancel()
        }
    }

    private enum Constants {
        static let contentMinHeight: CGFloat = 160
        static let contentMaxHeight: CGFloat = 440
    }
}

private struct NoteCreateSheetDetentsModifier: ViewModifier {
    let isDynamic: Bool
    let headerHeight: CGFloat
    let contentHeight: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat

    func body(content: Content) -> some View {
        if isDynamic {
            content.presentationDetents(
                headerHeight > 0 && contentHeight > 0
                    ? [.height(min(max(headerHeight + contentHeight, minHeight), maxHeight)), .large]
                    : [.medium, .large]
            )
        } else {
            content.folioDynamicSheet(minHeight: minHeight, maxHeight: maxHeight)
        }
    }
}

private extension View {
    func noteCreateSheetDetents(
        isDynamic: Bool,
        headerHeight: CGFloat,
        contentHeight: CGFloat,
        minHeight: CGFloat,
        maxHeight: CGFloat
    ) -> some View {
        modifier(
            NoteCreateSheetDetentsModifier(
                isDynamic: isDynamic,
                headerHeight: headerHeight,
                contentHeight: contentHeight,
                minHeight: minHeight,
                maxHeight: maxHeight
            )
        )
    }
}
