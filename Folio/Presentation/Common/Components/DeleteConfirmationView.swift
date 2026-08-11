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
        .font(.custom("CormorantGaramond-Medium", size: FolioFontSize.title2))
        .foregroundStyle(Color.folioInk)

      Text(message)
        .font(.system(size: FolioFontSize.bodySmall))
        .foregroundStyle(Color.folioInkMuted)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: FolioSpacing.md) {
        FolioSecondaryButton(
          title: String(localized: "Cancel"),
          action: onCancel
        )
        FolioDangerButton(
          title: String(localized: "Delete"),
          isLoading: isDeleting,
          action: onDelete
        )
      }
    }
    .padding(FolioSpacing.xl4)
    .frame(maxWidth: 390)
    .background(Color.folioSurfaceStrong)
    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xl2, style: .continuous))
    .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
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
    overlay {
      if isPresented {
        ZStack {
          Color.black.opacity(0.34)
            .ignoresSafeArea()

          DeleteConfirmationView(
            title: title,
            message: message,
            isDeleting: isDeleting,
            onCancel: onCancel,
            onDelete: onDelete
          )
          .padding(.horizontal, FolioSpacing.xl3)
          .padding(.bottom, FolioSpacing.xl4)
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .zIndex(1)
        .accessibilityAddTraits(.isModal)
      }
    }
    .animation(.easeInOut(duration: FolioDuration.fast), value: isPresented)
  }
}
