import SwiftUI

struct NoteDiscardConfirmationView: View {
    let title: String
    let message: String
    let onCancel: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        ZStack {
            Color.folioInk.opacity(0.2)
                .contentShape(Rectangle())
                .onTapGesture {}

            VStack(alignment: .leading, spacing: FolioSpacing.sm) {
                Text(title)
                    .font(.custom("CormorantGaramond-Medium", size: FolioFontSize.heading))
                    .foregroundStyle(Color.folioInk)

                Text(message)
                    .font(.system(size: FolioFontSize.bodySmall))
                    .foregroundStyle(Color.folioInkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: FolioSpacing.lg) {
                    FolioSecondaryButton(
                        title: String(localized: "Cancel"),
                        action: onCancel
                    )

                    FolioDestructiveFilledButton(
                        title: String(localized: "Discard"),
                        action: onDiscard
                    )
                }
                .padding(.top, FolioSpacing.md)
            }
            .padding(FolioSpacing.xl3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.folioSurfaceStrong)
            .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xl2, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 24, y: 8)
            .padding(.horizontal, FolioSpacing.xl4)
            .accessibilityElement(children: .contain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
