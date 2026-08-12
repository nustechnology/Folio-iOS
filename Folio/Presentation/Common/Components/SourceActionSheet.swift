import SwiftUI

struct SourceActionSheet: View {
    let title: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.custom("CormorantGaramond-SemiBold", size: 28))
                .foregroundStyle(Color.folioTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.top, FolioSpacing.xl4)
                .padding(.bottom, FolioSpacing.xl3)

            VStack(spacing: FolioSpacing.md) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onEdit()
                    }
                } label: {
                    Text(String(localized: "Edit details"))
                        .font(.system(size: FolioFontSize.bodyLarge, weight: .semibold))
                        .foregroundStyle(Color.folioTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.folioSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: FolioRadius.md)
                                .stroke(Color.folioBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDelete()
                    }
                } label: {
                    Text(String(localized: "Delete source"))
                        .font(.system(size: FolioFontSize.bodyLarge, weight: .bold))
                        .foregroundStyle(Color.folioDanger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.folioDanger.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: FolioRadius.md)
                                .stroke(Color.folioDanger, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.bottom, FolioSpacing.xl3)
        }
        .frame(maxWidth: .infinity)
        .presentationBackground(Color.white)
        .presentationDetents([.height(236)])
        .presentationDragIndicator(.visible)
    }
}
