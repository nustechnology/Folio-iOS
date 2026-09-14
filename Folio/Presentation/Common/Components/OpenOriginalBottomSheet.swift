import SwiftUI

struct OpenOriginalBottomSheet: View {
    let fileName: String
    var sourceType: SourceType = .file
    let onCancel: () -> Void
    let onOpen: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Open source?"))
                .font(.system(size: 24, design: .serif))
                .foregroundStyle(Color.folioTextPrimary)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.top, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.sm)

            Text(sourceType == .web
                ? String(localized: "Opens the original link in another app on your device.")
                : String(localized: "Opens the original uploaded file in another app on your device."))
                .font(.system(size: 14))
                .foregroundStyle(Color.folioInkMuted)
                .lineSpacing(6)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl3)

            Text(sourceType == .web
                ? String(localized: "Link: \(fileName)")
                : String(localized: "File: \(fileName)"))
                .font(.system(size: 13))
                .foregroundStyle(Color.folioInkSoft)
                .lineLimit(1)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl4)

            HStack(spacing: 10) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onCancel()
                    }
                } label: {
                    Text(String(localized: "Cancel"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.folioTextPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.folioSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.folioRowBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onOpen()
                    }
                } label: {
                    Text(String(localized: "Open original ↗"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.folioOlive)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.bottom, FolioSpacing.xl)
        }
        .frame(maxWidth: .infinity)
        .background(Color.folioSurface)
        .presentationBackground(Color.folioSurface)
        .presentationDetents([.height(256)])
        .presentationDragIndicator(.visible)
    }
}
