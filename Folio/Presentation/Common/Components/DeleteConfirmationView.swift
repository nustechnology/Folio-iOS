import SwiftUI

struct DeleteConfirmationView: View {
  let title: String
  let message: String
  var isDeleting = false
  let onCancel: () -> Void
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: FolioSpacing.xl) {
      Text(title)
        .font(.custom("CormorantGaramond-Medium", size: FolioFontSize.heading))
        .foregroundStyle(Color.folioInk)

      Text(message)
        .font(.system(size: FolioFontSize.bodySmall))
        .foregroundStyle(Color.folioInkMuted)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: FolioSpacing.md) {
        FolioSecondaryButton(
          title: String(localized: "Cancel"),
          isDisabled: isDeleting,
          action: onCancel
        )
        FolioDangerButton(
          title: String(localized: "Delete"),
          isLoading: isDeleting,
          action: onDelete
        )
      }
    }
    .padding(.horizontal, FolioSpacing.xl4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
  }
}

extension View {
  func deleteConfirmationOverlay(
    isPresented: Bool,
    title: String,
    message: String,
    isDeleting: Bool = false,
    onCancel: @escaping () -> Void,
    onDelete: @escaping () -> Void
  ) -> some View {
    sheet(
      isPresented: Binding(
        get: { isPresented },
        set: { if !$0 { onCancel() } }
      )
    ) {
      DeleteConfirmationView(
        title: title,
        message: message,
        isDeleting: isDeleting,
        onCancel: onCancel,
        onDelete: onDelete
      )
      .presentationDetents([.height(200)])
      .presentationDragIndicator(.visible)
      .presentationBackground(Color.folioSurfaceStrong)
      .presentationCornerRadius(FolioRadius.xl2)
      .interactiveDismissDisabled(isDeleting)
    }
  }
}
