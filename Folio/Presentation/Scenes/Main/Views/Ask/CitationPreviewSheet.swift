import SwiftUI

// MARK: - Citation preview sheet (mirrors CitationPreviewBottomSheet.kt)

struct CitationPreviewSheet: View {
    let citation: AskCitation
    let onOpenInSource: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Citation")
                .font(.custom("CormorantGaramond-SemiBold", size: 28))
                .foregroundStyle(Color.folioInk)
            Text("Citation \(citation.index)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.folioInkMuted)

            HStack(alignment: .top, spacing: 10) {
                Text(citation.sourceTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.folioInk)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text(citation.badgeLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.folioInkMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.folioSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            if !citation.locationLabel.isEmpty {
                Text(citation.locationLabel)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.folioInkMuted)
            }

            Text("Evidence")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.folioInkMuted)

            ScrollView {
                Text(citation.evidenceText.isEmpty ? String(localized: "No evidence text available.") : citation.evidenceText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.folioInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .frame(minHeight: 88, maxHeight: 220)
            .background(Color.folioSurfaceStrong)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.folioLine, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.folioInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.folioSurfaceStrong)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.folioLine, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    onOpenInSource()
                    dismiss()
                } label: {
                    Text("Open in source")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(citation.canOpenInSource ? 1 : 0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.folioOliveDark.opacity(citation.canOpenInSource ? 1 : 0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!citation.canOpenInSource)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.white)
    }
}
