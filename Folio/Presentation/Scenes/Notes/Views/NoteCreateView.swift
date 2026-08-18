import SwiftUI

struct NoteCreateView: View {
    @ObservedObject var viewModel: NoteListViewModel

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: FolioRadius.handle)
                .fill(Color.folioHomeSheetHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioRadius.handle * 2)
                .padding(.top, FolioSpacing.sm)
                .padding(.bottom, FolioSpacing.xl3)

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
                VStack(alignment: .leading, spacing: FolioSpacing.xl) {
                    FolioTextField(
                        label: String(localized: "Title"),
                        placeholder: String(localized: "Untitled Note"),
                        text: titleBinding,
                        style: .singleLine,
                        error: viewModel.state.createTitleError
                    )
                    .disabled(viewModel.state.isCreating)

                    FolioTextField(
                        label: String(localized: "Content"),
                        placeholder: String(localized: "What stood out, and why does it matter for this research?"),
                        text: contentBinding,
                        style: .multiline(minHeight: Constants.contentMinHeight, maxHeight: Constants.contentMaxHeight),
                        error: viewModel.state.createContentError
                    )
                    .disabled(viewModel.state.isCreating)

                    HStack {
                        Spacer()
                        Text("\(viewModel.state.createContent.count) / \(Constants.maximumContentLengthLabel)")
                            .font(.system(size: FolioFontSize.caption2))
                            .foregroundStyle(
                                viewModel.state.createContent.count > NoteLimits.maximumContentLength
                                    ? Color.folioDanger
                                    : Color.folioInkSoft
                            )
                    }
                    .padding(.top, -FolioSpacing.lg)

                    actionButtons
                }
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl)
            }
        }
        .background(Color.folioHomeSheetBackground)
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(FolioRadius.xl2)
        .folioDynamicSheet(minHeight: FolioSize.noteCreateSheetMinH, maxHeight: FolioSize.noteCreateSheetMaxH)
        .presentationDragIndicator(.hidden)
        .interceptInteractiveDismiss(
            isBlocked: viewModel.state.isCreating || viewModel.hasCreateDraft,
            onAttemptToDismiss: { viewModel.handle(.createDismissalAttempted) }
        )
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
        }
    }

    private var isSaveDisabled: Bool {
        let titleTooLong = viewModel.state.createTitle.count > NoteLimits.maximumTitleLength
        let content = viewModel.state.createContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentInvalid = content.isEmpty || viewModel.state.createContent.count > NoteLimits.maximumContentLength
        return titleTooLong || contentInvalid || viewModel.state.isCreating
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { viewModel.state.createTitle },
            set: { viewModel.handle(.createTitleChanged($0)) }
        )
    }

    private var contentBinding: Binding<String> {
        Binding(
            get: { viewModel.state.createContent },
            set: { viewModel.handle(.createContentChanged($0)) }
        )
    }

    private enum Constants {
        static let contentMinHeight: CGFloat = 140
        static let contentMaxHeight: CGFloat = 220

        static let maximumContentLengthLabel: String = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: NoteLimits.maximumContentLength))
                ?? "\(NoteLimits.maximumContentLength)"
        }()
    }
}
