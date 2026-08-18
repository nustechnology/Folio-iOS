import SwiftUI

struct ConfirmationBottomSheet: View {
    let title: String
    let message: String
    var cancelTitle: String = String(localized: "Cancel")
    var confirmTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.custom("CormorantGaramond-SemiBold", size: 26))
                .foregroundStyle(Color.folioTextPrimary)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.top, FolioSpacing.xl)
                .padding(.bottom, FolioSpacing.sm)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.folioInkMuted)
                .lineSpacing(6)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl)

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text(cancelTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.folioTextPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.folioSurfaceStrong)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.folioRowBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.folioDanger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.folioDanger.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.folioDanger, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.bottom, FolioSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .background(Color.folioSurfaceStrong)
        .presentationBackground(Color.folioSurfaceStrong)
        .presentationDetents([.height(180)])
        .presentationDragIndicator(.visible)
    }
}
