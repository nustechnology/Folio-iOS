import SwiftUI

struct NoteActionSheet: View {
    let note: NoteSummary
    let onView: () -> Void
    let onEdit: () -> Void
    let onConvert: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: FolioRadius.handle)
                .fill(Color.folioHomeSheetHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioSize.dragHandleH)
                .padding(.bottom, FolioSpacing.xl3)

            Text(note.title)
                .font(.custom("CormorantGaramond-Medium", size: FolioFontSize.heading))
                .foregroundStyle(Color.folioInk)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl3)

            VStack(spacing: FolioSpacing.lg) {
                FolioSecondaryButton(title: String(localized: "View"), action: onView)
                FolioSecondaryButton(title: String(localized: "Edit"), action: onEdit)
                FolioSecondaryButton(title: String(localized: "Convert to source"), action: onConvert)
                FolioDangerButton(title: String(localized: "Delete"), action: onDelete)
            }
            .padding(.horizontal, FolioSpacing.xl3)
        }
        .background(Color.folioHomeSheetBackground)
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(FolioRadius.xl2)
        .folioDynamicSheet(minHeight: FolioSize.noteActionSheetMinH, maxHeight: FolioSize.noteActionSheetMaxH)
        .presentationDragIndicator(.hidden)
    }
}
