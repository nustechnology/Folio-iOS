import SwiftUI

struct NoteCreateView: View {
    @ObservedObject var viewModel: NoteListViewModel
    @StateObject private var editingModel: NoteRichTextEditingModel
    @State private var toast: ToastMessage?

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
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: FolioRadius.handle)
                .fill(Color.folioHomeSheetHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioRadius.handle * 2)
                .padding(.top, FolioSpacing.sm)
                .padding(.bottom, FolioSpacing.xl2)
            
            VStack(alignment: .leading, spacing: FolioSpacing.sm) {
                Text(String(localized: "New note"))
                    .font(.custom("CormorantGaramond-Medium", size: FolioFontSize.heading))
                    .foregroundStyle(Color.folioInk)
                
                Text(String(localized: "Capture ideas, quotes and observations for this space."))
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
                        text: titleBinding,
                        style: .singleLine,
                        error: viewModel.state.createTitleError
                    )
                    .disabled(viewModel.state.isCreating)
                    
                    HStack {
                        Spacer()
                        Text("\(viewModel.state.createTitle.count) / 150")
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
                    
                    if let error = viewModel.state.createContentError {
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
                                if !isEditing { viewModel.handle(.createContentEditingEnded) }
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
                                viewModel.state.createContentError == nil ? Color.folioFieldBorder : Color.folioDanger,
                                lineWidth: 1
                            )
                    )
                    .disabled(viewModel.state.isCreating)
                    
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
            isBlocked: viewModel.state.isCreating || viewModel.hasCreateDraft,
            onAttemptToDismiss: { viewModel.handle(.createDismissalAttempted) }
        )
        .onAppear {
            editingModel.attributedText = FolioRichTextEditor.attributedTextFromHTML(viewModel.state.createContent)
        }
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
        .fullScreenCover(
            isPresented: Binding(
                get: { viewModel.state.isDiscardCreateDraftPresented },
                set: { if !$0 { viewModel.handle(.createDiscardCancelled) } }
            )
        ) {
            NoteDiscardConfirmationView(
                title: String(localized: "Discard unsaved note?"),
                message: String(localized: "Your unsaved note will be lost."),
                onCancel: { viewModel.handle(.createDiscardCancelled) },
                onDiscard: { viewModel.handle(.createDiscardConfirmed) }
            )
            .presentationBackground(.clear)
            .interactiveDismissDisabled(true)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: FolioSpacing.lg) {
            FolioSecondaryButton(
                title: String(localized: "Cancel"),
                isDisabled: viewModel.state.isCreating,
                action: { viewModel.handle(.createCancelTapped) }
            )
            
            FolioPrimaryButton(
                title: String(localized: "Save note"),
                isLoading: viewModel.state.isCreating,
                isEnabled: !isSaveDisabled,
                action: { viewModel.handle(.createSaveTapped) }
            )
        }.padding(.top, FolioSpacing.sm)
    }
    
    private var isSaveDisabled: Bool {
        let titleTooLong = viewModel.state.createTitle.count > NoteLimits.maximumTitleLength
        let content = NoteLimits.plainText(from: viewModel.state.createContent)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let contentInvalid = content.isEmpty || viewModel.state.createContentError != nil
        return titleTooLong || contentInvalid || viewModel.state.isCreating
    }
    
    private var titleBinding: Binding<String> {
        Binding(
            get: { viewModel.state.createTitle },
            set: { viewModel.handle(.createTitleChanged($0)) }
        )
    }
    
    private var plainText: String { NoteLimits.plainText(from: viewModel.state.createContent) }
    
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
