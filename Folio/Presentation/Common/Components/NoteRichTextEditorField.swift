import SwiftUI

struct NoteRichTextEditorField: View {
    @ObservedObject var editingModel: NoteRichTextEditingModel
    let onContentEditingEnded: () -> Void
    var onLinkSelectionFailed: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
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

            ZStack(alignment: .top) {
                FolioRichTextEditor(
                    attributedText: $editingModel.attributedText,
                    selectedRange: $editingModel.selectedRange,
                    typingAttributes: $editingModel.typingAttributes,
                    onTextChange: editingModel.textChanged,
                    onEditingChanged: { isEditing in
                        if !isEditing { onContentEditingEnded() }
                    },
                    textContainerTopInset: 16
                )

                if editingModel.attributedText.string.isEmpty {
                    Text(String(localized: "What stood out, and why does it matter for this research?"))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.folioInkSoft.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func presentLinkPrompt() {
        if !editingModel.presentLinkPrompt() {
            onLinkSelectionFailed()
        }
    }
}
