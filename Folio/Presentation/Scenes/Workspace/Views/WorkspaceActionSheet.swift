import SwiftUI

struct WorkspaceActionSheet: View {
    let workspace: Workspace
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: FolioRadius.handle)
                .fill(Color.folioHomeSheetHandle)
                .frame(width: FolioSize.dragHandleW, height: FolioSize.dragHandleH)
                .padding(.bottom, FolioSpacing.xl3)

            Text(workspace.name)
                .font(.custom("CormorantGaramond-Medium", size: FolioFontSize.headingLarge))
                .foregroundStyle(Color.folioInk)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl3)

            VStack(spacing: FolioSpacing.lg) {
                FolioSecondaryButton(
                    title: String(localized: "Edit"),
                    action: {
                        dismiss()
                        onEdit()
                    }
                )
                FolioDangerButton(
                    title: String(localized: "Delete"),
                    action: {
                        dismiss()
                        onDelete()
                    }
                )
            }
            .padding(.horizontal, FolioSpacing.xl3)
        }
        .background(Color.folioHomeSheetBackground)
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationCornerRadius(FolioRadius.xl2)
        .folioDynamicSheet(minHeight: FolioSize.workspaceActionSheetMinH, maxHeight: FolioSize.workspaceActionSheetMaxH)
        .presentationDragIndicator(.hidden)
    }
}
