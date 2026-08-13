import SwiftUI

struct NoteEditView: View {
    let note: Note
    @ObservedObject var viewModel: NoteListViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: FolioRadius.handle)
                .fill(Color.folioHomeSheetHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioSize.dragHandleH)
                .padding(.top, FolioSpacing.sm)
                .padding(.bottom, FolioSpacing.lg)

            header

            ScrollView {
                VStack(alignment: .leading, spacing: FolioSpacing.xl2) {
                    FolioTextField(
                        label: String(localized: "Title"),
                        text: titleBinding,
                        style: .singleLine,
                        error: titleError
                    )

                    FolioTextField(
                        label: String(localized: "Content"),
                        placeholder: String(localized: "Write your note"),
                        text: contentBinding,
                        style: .multiline(minHeight: 160, maxHeight: 280)
                    )
                    actionButtons
                }
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl)
            }
        }
        .background(Color.folioHomeSheetBackground)
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(FolioRadius.xl2)
        .folioDynamicSheet(minHeight: FolioSize.noteEditSheetMinH, maxHeight: FolioSize.noteEditSheetMaxH)
        .presentationDragIndicator(.hidden)
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

    private var contentBinding: Binding<String> {
        Binding(
            get: { viewModel.state.editContent },
            set: { viewModel.handle(.editContentChanged($0)) }
        )
    }

    private var titleError: String? {
        viewModel.state.editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? String(localized: "Title cannot be empty")
            : nil
    }

    private var isSaveDisabled: Bool {
        titleError != nil || viewModel.state.isSaving
    }
}
