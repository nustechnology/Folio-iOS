import SwiftUI

struct NoteEditView: View {
    let note: Note
    @ObservedObject var viewModel: NoteListViewModel

    @Environment(\.dismiss) private var dismiss
    @StateObject private var editingModel: NoteRichTextEditingModel
    @State private var toast: ToastMessage?

    init(note: Note, viewModel: NoteListViewModel) {
        self.note = note
        self.viewModel = viewModel
        _editingModel = StateObject(
            wrappedValue: NoteRichTextEditingModel(
                attributedText: FolioRichTextEditor.attributedTextFromHTML(note.content),
                publishingHTML: { [viewModel] html in
                    viewModel.handle(.editContentChanged(html))
                }
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: FolioRadius.handle)
                .fill(Color.folioHomeSheetHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioSize.dragHandleH)
                .padding(.top, FolioSpacing.sm)
                .padding(.bottom, FolioSpacing.md)

            header

            ScrollView {
                VStack(alignment: .leading, spacing: FolioSpacing.lg) {
                    FolioTextField(
                        label: String(localized: "Title"),
                        text: titleBinding,
                        style: .singleLine,
                        error: titleError
                    )

                    HStack {
                        Spacer()
                        Text("\(viewModel.state.editTitle.count) / 150")
                            .font(.system(size: FolioFontSize.caption2))
                            .foregroundStyle(Color.folioInkSoft)
                    }
                    .padding(.top, FolioSpacing.sm)

                    Text(String(localized: "Content"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.folioHomeTypeTextText)

                    if let linkError = editingModel.linkError {
                        Text(linkError)
                            .font(.system(size: FolioFontSize.caption2))
                            .foregroundStyle(Color.folioDanger)
                    }

                    if let error = viewModel.state.editContentError {
                        Text(error)
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
                                if !isEditing { viewModel.handle(.editContentEditingEnded) }
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
                    .frame(minHeight: 160, maxHeight: 280)
                    .background(Color.folioSurfaceStrong)
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous)
                            .stroke(
                                viewModel.state.editContentError == nil ? Color.folioFieldBorder : Color.folioDanger,
                                lineWidth: 1
                            )
                    )
                    .disabled(viewModel.state.isSaving)

                    HStack {
                        Spacer()
                        Text("\(NoteLimits.plainText(from: viewModel.state.editContent).count) / \(NoteLimits.maximumContentLengthLabel)")
                            .font(.system(size: FolioFontSize.caption2))
                            .foregroundStyle(Color.folioInkSoft)
                    }
                    .padding(.top, FolioSpacing.sm)

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
        .folioDynamicSheet(minHeight: FolioSize.noteEditSheetMinH, maxHeight: FolioSize.noteEditSheetMaxH)
        .presentationDragIndicator(.hidden)
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
    }

    private var header: some View {
        HStack(alignment: .top, spacing: FolioSpacing.md) {
            VStack(alignment: .leading, spacing: FolioSpacing.sm) {
                Text(String(localized: "Edit note"))
                    .font(.custom("CormorantGaramond-Medium", size: FolioFontSize.heading))
                    .foregroundStyle(Color.folioInk)

                Text(String(localized: "Update the title and content for this note."))
                    .font(.system(size: FolioFontSize.bodySmall, weight: .regular))
                    .foregroundStyle(Color.folioInkMuted)
            }

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: FolioFontSize.body, weight: .medium))
                    .foregroundStyle(Color.folioInk)
                    .frame(width: FolioSize.buttonMd, height: FolioSize.buttonMd)
                    .background(Color.folioHomeSheetBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous)
                            .stroke(Color.folioHomeSheetHandle.opacity(0.8), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Close"))
        }
        .padding(.horizontal, FolioSpacing.xl3)
        .padding(.bottom, FolioSpacing.xl3)
    }

    private var actionButtons: some View {
        HStack(spacing: FolioSpacing.lg) {
            FolioDangerButton(
                title: String(localized: "Delete"),
                action: { viewModel.handle(.deleteRequested(note.summary)) }
            )

            FolioPrimaryButton(
                title: String(localized: "Save"),
                isLoading: viewModel.state.isSaving,
                isEnabled: !isSaveDisabled,
                action: { viewModel.handle(.editSaved(note)) }
            )
        }
        .padding(.top, FolioSpacing.sm)
        .padding(.bottom, FolioSpacing.xl)
        .background(Color.folioHomeSheetBackground)
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { viewModel.state.editTitle },
            set: { viewModel.handle(.editTitleChanged($0)) }
        )
    }

    private func presentLinkPrompt() {
        if !editingModel.presentLinkPrompt() {
            toast = .error(String(localized: "Select text to add a link"))
        }
    }

    private var titleError: String? {
        viewModel.state.editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? String(localized: "Title cannot be empty")
            : nil
    }

    private var isSaveDisabled: Bool {
        let content = NoteLimits.plainText(from: viewModel.state.editContent)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return titleError != nil || content.isEmpty || viewModel.state.editContentError != nil || viewModel.state.isSaving
    }
}
